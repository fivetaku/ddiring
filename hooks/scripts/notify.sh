#!/bin/bash
# ddiring — Stop/Notification 훅 알림 스크립트
# 알림 구성: 제목=프로젝트 폴더, 부제목=세션이 떠 있는 터미널/앱, 본문=마지막 사용자 프롬프트 요약
# macOS: terminal-notifier(클릭→앱 포커스) / osascript 폴백
# Windows (Git Bash, experimental): PowerShell 5.1 WinRT 토스트 (클릭 포커스 없음)
# 설정(환경변수):
#   DDIRING_SILENT=1   소리 끔 (macOS)
#   DDIRING_VOLUME     0.0~1.0 (기본 0.2, macOS)
#   DDIRING_SOUND      /System/Library/Sounds/*.aiff (기본 Glass, macOS)

case "$(uname -s)" in
  Darwin)               OS=mac ;;
  MINGW*|MSYS*|CYGWIN*) OS=win ;;
  *)                    exit 0 ;;   # 그 외 OS는 조용히 종료
esac

EVENT="${1:-stop}"   # stop | notification
INPUT=$(cat)

PYBIN=""
command -v python3 >/dev/null 2>&1 && PYBIN=python3
[ -z "$PYBIN" ] && command -v python >/dev/null 2>&1 && PYBIN=python

if [ -n "$PYBIN" ]; then
  eval "$(printf '%s' "$INPUT" | "$PYBIN" -c '
import sys, json, shlex
try: d = json.load(sys.stdin)
except Exception: d = {}
print("CWD=" + shlex.quote(d.get("cwd", "")))
print("FULL_SID=" + shlex.quote(d.get("session_id") or ""))
print("SID=" + shlex.quote((d.get("session_id") or "")[:8]))
print("TRANSCRIPT=" + shlex.quote(d.get("transcript_path", "")))
print("NMSG=" + shlex.quote(d.get("message", "")))
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

# ── 본문: 마지막 사용자 프롬프트 요약 (Notification 이벤트면 메시지 우선) ──
if [ "$EVENT" = "notification" ] && [ -n "${NMSG:-}" ]; then
  TASK="$NMSG"
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
    # 진짜 사용자 입력만 — 도구 결과·시스템 태그·인터럽트 표기는 건너뜀
    for line in reversed(lines):
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("type") != "user" or o.get("isMeta"):
            continue
        c = o.get("message", {}).get("content", "")
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
    # 폴백: last-prompt 레코드. 사이드체인(서브에이전트) 것일 수 있어 sessionId 일치만 채택
    for line in reversed(lines):
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("type") != "last-prompt":
            continue
        if sid and o.get("sessionId") and o.get("sessionId") != sid:
            continue
        t = (o.get("lastPrompt") or "").strip()
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

ICON="✅"; [ "$EVENT" = "notification" ] && ICON="⏸️"

# ── macOS 발화 ───────────────────────────────────────────────────
if [ "$OS" = mac ]; then
  if [ "${DDIRING_SILENT:-0}" != "1" ]; then
    afplay -v "${DDIRING_VOLUME:-0.2}" "${DDIRING_SOUND:-/System/Library/Sounds/Glass.aiff}" >/dev/null 2>&1 &
  fi
  BUNDLE="${__CFBundleIdentifier:-}"
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier \
      -title "$ICON $PROJ" \
      -subtitle "$APP" \
      -message "$TASK" \
      -group "ddiring-$PROJ-${SID:-x}" \
      ${BUNDLE:+-activate "$BUNDLE"} \
      >/dev/null 2>&1
  else
    osascript -e "display notification \"$(printf '%s' "$TASK" | sed 's/"/\\\\"/g')\" with title \"$ICON $PROJ\" subtitle \"$APP\"" >/dev/null 2>&1
  fi
  exit 0
fi

# ── Windows 발화 (experimental) ──────────────────────────────────
# PowerShell 5.1(powershell.exe) WinRT 원샷 토스트 — 외부 의존성 0.
# pwsh(PS7)는 WinRT 프로젝션이 없어 실패할 수 있으므로 반드시 powershell.exe 사용.
# 원샷 프로세스는 activation 이벤트를 못 받아 클릭 동작은 없음(표시 전용).
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
' >/dev/null 2>&1

exit 0
