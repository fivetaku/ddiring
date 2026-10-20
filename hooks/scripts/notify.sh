#!/bin/bash
# ddiring — Stop/Notification 훅 알림 스크립트
# 알림 구성: 제목=프로젝트 폴더, 부제목=세션이 떠 있는 터미널/앱,
#   본문=Stop이면 마지막 사용자 프롬프트 70자 요약 / Notification이면 이벤트 메시지 70자 요약
# macOS: terminal-notifier(클릭→앱 포커스) / osascript 폴백
# Windows (Git Bash, experimental): PowerShell 5.1 WinRT 토스트 (클릭 포커스 없음)
# 설정(환경변수):
#   DDIRING_SILENT=1     소리 끔 (macOS)
#   DDIRING_VOLUME       0.0~1.0 (기본 0.2, macOS)
#   DDIRING_SOUND        /System/Library/Sounds/*.aiff (기본 Glass, macOS)
#   DDIRING_HIDE_BODY=1  본문 숨김(프롬프트 대신 고정 문구 — 잠금화면/화면공유 프라이버시)
#   DDIRING_DEBUG=1      실패 사유를 ${TMPDIR:-/tmp}/ddiring.log 에 기록
# 관측: 마지막 발화 상태 1줄이 항상 ~/.cache/ddiring/last-notify 에 남는다

case "$(uname -s)" in
  Darwin)               OS=mac ;;
  MINGW*|MSYS*|CYGWIN*) OS=win ;;
  *)                    exit 0 ;;   # 그 외 OS는 조용히 종료
esac

debug() {
  [ "${DDIRING_DEBUG:-0}" = "1" ] || return 0
  printf '%s %s\n' "$(date '+%H:%M:%S' 2>/dev/null)" "$*" >> "${TMPDIR:-/tmp}/ddiring.log" 2>/dev/null
}

# 마지막 발화 상태 1줄 — 항상 기록(고정 크기, HOME 기준 고정 경로).
# "소리만 나고 배너가 없다" 류 무음 실패를 사후 진단 가능하게 하는 관측 창구.
status() {
  mkdir -p "$HOME/.cache/ddiring" 2>/dev/null
  printf '%s %s\n' "$(date '+%F %H:%M:%S' 2>/dev/null)" "$*" > "$HOME/.cache/ddiring/last-notify" 2>/dev/null
}

EVENT="${1:-stop}"   # stop | notification
INPUT=$(cat)

PYBIN=""
command -v python3 >/dev/null 2>&1 && PYBIN=python3
[ -z "$PYBIN" ] && command -v python >/dev/null 2>&1 && PYBIN=python

if [ -n "$PYBIN" ]; then
  # shlex.quote로 감싼 단일 단어만 출력하므로 문자열 값으로는 셸 구문 삽입 불가.
  # 비문자열 타입(JSON 숫자/배열 등)은 빈 문자열로 강제해 부분 출력/예외를 막는다.
  eval "$(printf '%s' "$INPUT" | "$PYBIN" -c '
import sys, json, shlex
try: d = json.load(sys.stdin)
except Exception: d = {}
if not isinstance(d, dict): d = {}
def text(k):
    v = d.get(k, "")
    return v if isinstance(v, str) else ""
sid = text("session_id")
print("CWD=" + shlex.quote(text("cwd")))
print("FULL_SID=" + shlex.quote(sid))
print("SID=" + shlex.quote(sid[:8]))
print("TRANSCRIPT=" + shlex.quote(text("transcript_path")))
print("NMSG=" + shlex.quote(text("message")))
' 2>/dev/null)"
fi
[ -z "${CWD:-}" ] && CWD="$PWD"
PROJ=$(basename "$CWD")

# ── 어느 터미널/앱에서 돌던 세션인지 ──────────────────────────────
detect_app_mac() {
  # macOS: claude 프로세스가 물려받은 __CFBundleIdentifier로 호스트 앱 식별
  # 매핑 근거: 2026-08-23 리서치 (로컬 Info.plist·Homebrew cask·공식 저장소 실측)
  case "${__CFBundleIdentifier:-}" in
    com.apple.Terminal)               echo "Terminal" ;;
    com.googlecode.iterm2)            echo "iTerm" ;;
    com.microsoft.VSCode)             echo "VS Code" ;;
    com.microsoft.VSCodeInsiders)     echo "VS Code Insiders" ;;
    com.vscodium*)                    echo "VSCodium" ;;
    com.todesktop.230313mzl4w4u92)    echo "Cursor" ;;   # 고정 ID — com.todesktop.* 와일드카드는 타 ToDesktop 앱 오탐
    com.exafunction.windsurf*)        echo "Windsurf (Devin)" ;;
    com.google.antigravity*)          echo "Antigravity" ;;   # 신버전 -ide 접미 없음 → prefix
    dev.warp.Warp*)                   echo "Warp" ;;
    com.mitchellh.ghostty)            echo "Ghostty" ;;
    org.alacritty)                    echo "Alacritty" ;;
    net.kovidgoyal.kitty)             echo "kitty" ;;
    com.github.wez.wezterm)           echo "WezTerm" ;;
    org.tabby|Tabby*)                 echo "Tabby" ;;
    co.zeit.hyper)                    echo "Hyper" ;;
    dev.zed.Zed*)                     echo "Zed" ;;
    com.jetbrains.*|com.google.android.studio*) echo "JetBrains" ;;
    com.raphaelamorim.rio)            echo "Rio" ;;
    com.termius-dmg.mac)              echo "Termius" ;;
    dev.commandline.waveterm)         echo "Wave" ;;
    com.rstudio.positron)             echo "Positron" ;;
    dev.kiro.desktop)                 echo "Kiro" ;;
    com.trae.app)                     echo "Trae" ;;
    com.apple.dt.Xcode)               echo "Xcode" ;;
    # ── Claude Code 멀티세션 매니저 ──
    sh.paseo.*)                       echo "Paseo" ;;
    com.cmuxterm.app*)                echo "cmux" ;;
    com.conductor.app)                echo "Conductor" ;;
    com.stablyai.orca)                echo "Orca" ;;
    com.electron.sculptor)            echo "Sculptor" ;;
    com.superset.desktop*)            echo "Superset" ;;
    com.stravu.crystal)               echo "Crystal" ;;
    sh.waku*)                         echo "Waku" ;;
    com.jean.desktop)                 echo "Jean" ;;
    com.fletch.desktop)               echo "Fletch" ;;
    com.constellagent.app)            echo "Constellagent" ;;
    dev.graphcode.app)                echo "GraphCode" ;;
    com.clave.app)                    echo "Clave" ;;
    com.mux.app)                      echo "Xum" ;;
    "")                               echo "${TERM_PROGRAM:-CLI}" ;;
    *)                                echo "${TERM_PROGRAM:-$__CFBundleIdentifier}" ;;
  esac
}

detect_app_win() {
  # Windows: 만능 변수가 없어 env 2단 판별 — 안쪽(가장 최근 세팅) 변수 우선.
  # WT_SESSION 등은 자식 앱에도 상속되므로 TERM_PROGRAM=vscode를 먼저 검사한다.
  if [ "${TERM_PROGRAM:-}" = "vscode" ]; then echo "VS Code"
  elif [ -n "${WT_SESSION:-}" ];        then echo "Windows Terminal"
  elif [ -n "${ConEmuPID:-}" ];         then echo "ConEmu"
  elif [ "${TERM_PROGRAM:-}" = "mintty" ]; then echo "Git Bash"
  else echo "${TERM_PROGRAM:-Terminal}"
  fi
}

if [ "$OS" = mac ]; then APP=$(detect_app_mac); else APP=$(detect_app_win); fi

# ── 본문 70자 요약 (공백 정규화 + 제어문자 제거) ─────────────────
clip_text() {
  if [ -n "$PYBIN" ]; then
    printf '%s' "$1" | "$PYBIN" -c '
import sys
t = "".join(ch for ch in sys.stdin.read() if ord(ch) >= 32 and ord(ch) != 127)
t = " ".join(t.split())
sys.stdout.write(t[:70] + ("…" if len(t) > 70 else ""))
' 2>/dev/null
  else
    printf '%.70s' "$1" | tr -d '\n\r'
  fi
}

# ── 본문: Stop=마지막 사용자 프롬프트 / Notification=이벤트 메시지 ──
if [ "$EVENT" = "notification" ] && [ -n "${NMSG:-}" ]; then
  TASK=$(clip_text "$NMSG")
elif [ -n "$PYBIN" ]; then
  TASK=$("$PYBIN" - "${TRANSCRIPT:-}" "${FULL_SID:-}" <<'PYEOF' 2>/dev/null
import sys, json, os
path = sys.argv[1] if len(sys.argv) > 1 else ""
sid = sys.argv[2] if len(sys.argv) > 2 else ""
if not path or not os.path.isfile(path):
    sys.exit()

def clip(t):
    t = " ".join(t.split())
    return t[:70] + ("…" if len(t) > 70 else "")

def read_tail(size):
    with open(path, "rb") as f:
        try:
            f.seek(-size, 2)
        except OSError:
            f.seek(0)
        return f.read().decode("utf-8", "ignore").splitlines()

def scan_user(lines):
    # 진짜 사용자 입력만 — 도구 결과·시스템 태그(<로 시작)·인터럽트 표기는 건너뜀.
    # (드물게 '<'로 시작하는 정상 프롬프트도 건너뛰는 알려진 트레이드오프 —
    #  합성 태그 종류가 다양해 allowlist보다 안전한 쪽을 택함)
    for line in reversed(lines):
        try:
            o = json.loads(line)
        except Exception:
            continue
        if not isinstance(o, dict):
            continue
        if o.get("type") != "user" or o.get("isMeta"):
            continue
        m = o.get("message")
        if not isinstance(m, dict):
            continue
        c = m.get("content", "")
        if isinstance(c, list):
            c = " ".join(p.get("text", "") for p in c if isinstance(p, dict) and p.get("type") == "text")
        if not isinstance(c, str):
            continue
        t = c.strip()
        if not t or t.startswith("<") or t.startswith("[Request interrupted"):
            continue
        return clip(t)
    return ""

def scan_last_prompt(lines):
    # 폴백: last-prompt 레코드. 사이드체인(서브에이전트) 것일 수 있으므로
    # sid가 있으면 sessionId가 정확히 일치하는 레코드만 채택(무표기 레코드도 거부)
    for line in reversed(lines):
        try:
            o = json.loads(line)
        except Exception:
            continue
        if not isinstance(o, dict) or o.get("type") != "last-prompt":
            continue
        if sid and o.get("sessionId") != sid:
            continue
        t = o.get("lastPrompt")
        if not isinstance(t, str):
            continue
        t = t.strip()
        if t and not t.startswith("<"):
            return clip(t)
    return ""

# 1) 꼬리 200KB → 2) 도구 결과가 꼬리를 채운 세션 대비 2MB 확장 → 3) last-prompt 폴백
lines = read_tail(200_000)
out = scan_user(lines)
if not out:
    lines = read_tail(2_000_000)
    out = scan_user(lines)
if not out:
    out = scan_last_prompt(lines)
if out:
    print(out)
PYEOF
)
fi
[ -z "${TASK:-}" ] && TASK="작업 완료 (Done)"
[ "${DDIRING_HIDE_BODY:-0}" = "1" ] && TASK="작업 완료 (Done)"

ICON="✅"; [ "$EVENT" = "notification" ] && ICON="⏸️"

# ── macOS 발화 ───────────────────────────────────────────────────
if [ "$OS" = mac ]; then
  if [ "${DDIRING_SILENT:-0}" != "1" ]; then
    afplay -v "${DDIRING_VOLUME:-0.2}" "${DDIRING_SOUND:-/System/Library/Sounds/Glass.aiff}" >/dev/null 2>&1 &
  fi
  BUNDLE="${__CFBundleIdentifier:-}"
  # -activate에 넘길 번들 ID는 형식 검증(예상 밖 문자면 미사용)
  case "$BUNDLE" in
    *[!A-Za-z0-9._-]*) BUNDLE="" ;;
  esac
  # terminal-notifier 탐색은 PATH에 의존하면 안 된다 — 데몬/GUI 기동 세션의 훅은
  # homebrew 경로가 빠진 최소 PATH로 실행되어 폴백으로 새고, osascript 폴백은
  # 알림 권한이 없으면 exit 0인 채 배너를 조용히 버린다(소리만 나는 반쪽 알림).
  TN=""
  if command -v terminal-notifier >/dev/null 2>&1; then
    TN=$(command -v terminal-notifier)
  else
    for _c in /opt/homebrew/bin/terminal-notifier /usr/local/bin/terminal-notifier; do
      [ -x "$_c" ] && { TN="$_c"; break; }
    done
  fi
  if [ -n "$TN" ]; then
    TN_ARGS=(
      -title "$ICON $PROJ"
      -subtitle "$APP"
      -message "$TASK"
      -group "ddiring-$PROJ-${SID:-x}"
    )
    # Keep ddiring as the sender. The board only resolves a click to an exact
    # current session; an identified original app remains the fallback.
    # Stream Deck replaces its bundled Node on update, so pick whichever version is
    # installed instead of pinning one. Both paths can be overridden.
    BOARD_NODE="${DDIRING_BOARD_NODE:-}"
    if [ -z "$BOARD_NODE" ]; then
      for n in "$HOME/Library/Application Support/com.elgato.StreamDeck/NodeJS/"*/node; do
        [ -x "$n" ] && BOARD_NODE="$n"
      done
    fi
    BOARD_COMMAND="${DDIRING_BOARD_COMMAND:-$HOME/streamdeck-dev/30-plugins/com.gptaku.cc-control.sdPlugin/bin/board-command.js}"
    if [ -n "${FULL_SID:-}" ] && [ -x "$BOARD_NODE" ] && [ -f "$BOARD_COMMAND" ] &&
       CLICK_COMMAND=$("$BOARD_NODE" "$BOARD_COMMAND" click-command "$FULL_SID" "$BUNDLE" 2>/dev/null) &&
       [ -n "$CLICK_COMMAND" ]; then
      TN_ARGS+=( -execute "$CLICK_COMMAND" )
    elif [ -n "$BUNDLE" ]; then
      TN_ARGS+=( -activate "$BUNDLE" )
    fi
    if "$TN" "${TN_ARGS[@]}" >/dev/null 2>&1; then
      status "tn ok ($TN) proj=$PROJ app=$APP"
    else
      status "tn FAILED rc=$? ($TN) proj=$PROJ"; debug "terminal-notifier failed"
    fi
  else
    # AppleScript 소스는 고정, 사용자 데이터는 argv로만 전달(언어 계층 인젝션 차단)
    # 주의: 이 경로는 osascript에 알림 권한이 없으면 exit 0이어도 배너가 표시되지
    # 않는다 — status 파일에 폴백 사용을 남겨 무음 실패를 진단 가능하게 한다.
    if osascript - "$TASK" "$ICON $PROJ" "$APP" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title (item 2 of argv) subtitle (item 3 of argv)
end run
APPLESCRIPT
    then
      status "fallback-osascript rc=0 (tn not found; 권한 없으면 배너 미표시 가능) proj=$PROJ"
    else
      status "fallback-osascript FAILED rc=$? proj=$PROJ"; debug "osascript failed"
    fi
  fi
  exit 0
fi

# ── Windows 발화 (experimental) ──────────────────────────────────
# PowerShell 5.1(powershell.exe) WinRT 원샷 토스트 — 토스트 백엔드 자체는 의존성 0.
# (본문 추출은 위에서 Python 3 필요 — 없으면 고정 문구로 폴백)
# pwsh(PS7)는 WinRT 프로젝션이 없어 실패할 수 있으므로 반드시 powershell.exe 사용.
# 원샷 프로세스는 activation 이벤트를 못 받아 클릭 동작은 없음(표시 전용).
if ! command -v powershell.exe >/dev/null 2>&1; then
  debug "powershell.exe not found"
  exit 0
fi
export DDIRING_T="$ICON $PROJ · $APP"
export DDIRING_B="$TASK"
powershell.exe -NoProfile -NonInteractive -Command '
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
$x = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$t = $x.GetElementsByTagName("text")
$t.Item(0).AppendChild($x.CreateTextNode($env:DDIRING_T)) | Out-Null
$t.Item(1).AppendChild($x.CreateTextNode($env:DDIRING_B)) | Out-Null
$appid = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appid).Show([Windows.UI.Notifications.ToastNotification]::new($x))
' >/dev/null 2>&1 || debug "PowerShell toast failed: $?"

exit 0
