#!/usr/bin/env bash
# ddiring doctor — "알림이 실제로 화면에 떴는가"를 검증한다.
#
# 존재 이유: notify.sh는 알림 "발사"까지만 책임진다. 발사가 성공해도(exit 0) macOS가
# 표시를 삼키는 경우가 있고(화면 공유/미러링 중, 집중 모드, 알림 권한 미허용), 그때
# ddiring은 소리만 나고 배너가 없는 반쪽 알림이 된다. 사용자 입장에서는 "플러그인이
# 고장났다"로 보이지만 실제로는 OS 설정 문제라 플러그인 로그만 봐서는 알 수 없다.
# 이 스크립트는 테스트 알림을 한 번 쏘고, OS 쪽 근거를 읽어 "표시됐는지"와
# "표시되지 않았다면 왜인지"를 판정한다.
#
# 근거 3계층 (위에서부터 신뢰도 순, 각각 없으면 다음으로 폴백):
#   1. donotdisturbd 로그의 판정 결과 — OS가 직접 남긴 outcome/reason (가장 정확)
#   2. 알림센터 DB(usernoted)의 presented 플래그 — 실제 표시 여부의 사후 기록
#   3. 설정 파일 정황 — 집중 모드 assertion, "미러링/공유 중 방해금지" 설정값
#
# 출력은 언어 중립 key=value 라인 + verdict 한 줄. 사용자 언어로의 설명은 호출자
# (커맨드/스킬)가 맡는다 — bash에 번역을 박지 않기 위한 분리.
#
# 사용법:
#   doctor.sh          진단 실행 (테스트 알림 1회 발사)
#   doctor.sh --quiet  동일하되 verdict 라인만 출력
set -uo pipefail

QUIET=0
[ "${1:-}" = "--quiet" ] && QUIET=1

emit() { [ "$QUIET" = "1" ] || printf '%s\n' "$*"; }

# 시간 제한 실행. `timeout`은 stock macOS에 없다(coreutils 설치 시에만 존재) —
# 훅은 최소 PATH로 도는 일이 많아 timeout에 의존하면 로그 조회가 통째로 조용히
# 실패해 "근거 없음"으로 오진한다. 그래서 백그라운드 + 폴링으로 직접 제한한다.
run_bounded() {  # $1=제한 초, 나머지=실행할 명령
  secs=$1; shift
  tmpf=$(mktemp 2>/dev/null) || return 1
  "$@" >"$tmpf" 2>/dev/null &
  bpid=$!
  i=0; limit=$((secs * 10))
  while kill -0 "$bpid" 2>/dev/null && [ "$i" -lt "$limit" ]; do
    sleep 0.1
    i=$((i + 1))
  done
  if kill -0 "$bpid" 2>/dev/null; then
    kill -TERM "$bpid" 2>/dev/null
    sleep 0.2
    kill -KILL "$bpid" 2>/dev/null
  fi
  wait "$bpid" 2>/dev/null
  cat "$tmpf" 2>/dev/null
  rm -f "$tmpf" 2>/dev/null
}

if [ "$(uname -s)" != "Darwin" ]; then
  emit "DDIRING_DOCTOR 1"
  emit "os=$(uname -s)"
  echo "verdict=UNSUPPORTED_OS"
  exit 0
fi

emit "DDIRING_DOCTOR 1"
emit "os=mac"

PYBIN=""
command -v python3 >/dev/null 2>&1 && PYBIN=python3

# ── 1. 알림 발사 (notify.sh와 동일한 탐색 순서: PATH 비의존) ───────────────
# 훅은 최소 PATH로 실행될 수 있어 PATH에만 의존하면 폴백으로 새므로 절대경로도 본다.
TN=""
if command -v terminal-notifier >/dev/null 2>&1; then
  TN=$(command -v terminal-notifier)
else
  for c in /opt/homebrew/bin/terminal-notifier /usr/local/bin/terminal-notifier; do
    [ -x "$c" ] && { TN="$c"; break; }
  done
fi

if [ -n "$TN" ]; then
  NOTIFIER=terminal-notifier
  BUNDLE=fr.julienxx.oss.terminal-notifier
  emit "notifier=terminal-notifier"
  emit "notifier_path=$TN"
else
  NOTIFIER=osascript
  # osascript 알림은 스크립트 편집기 명의로 전달된다. 알림센터가 기록하는 표기는
  # 전부 소문자이고 SQL `=`·grep -F는 대소문자를 가리므로, 여기 표기를 틀리면
  # "기록 없음"으로 읽혀 권한 문제로 오진한다 (실측으로 잡은 함정).
  BUNDLE=com.apple.scripteditor2
  emit "notifier=osascript"
fi
emit "bundle=$BUNDLE"

# 로그 조회 시작 시각(로컬) — 발사 직전으로 잡아야 이번 알림의 판정만 걸린다
SINCE=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)

FIRED=fail
if [ -n "$TN" ]; then
  "$TN" -title "ddiring ✅" -subtitle "self-check" \
        -message "알림 표시 점검 / notification display check" \
        -group "ddiring-doctor" >/dev/null 2>&1 && FIRED=ok
else
  osascript -e 'display notification "알림 표시 점검 / notification display check" with title "ddiring ✅" subtitle "self-check"' >/dev/null 2>&1 && FIRED=ok
fi
emit "fired=$FIRED"

# 알림 파이프라인(발사 → usernoted 전달 → DND 판정 → DB 기록)이 끝날 시간을 준다
sleep 3

# ── 2. OS의 판정 결과 읽기 (가장 신뢰도 높은 근거) ────────────────────────
# donotdisturbd가 알림마다 "outcome: suppressed; reason: <이유>"를 남긴다.
# 이 줄이 있으면 표시 여부와 그 이유를 추측 없이 확정할 수 있다.
OUTCOME=unknown
REASON=""
if [ -n "$SINCE" ]; then
  LOGLINE=$(run_bounded 30 log show --start "$SINCE" --style compact \
              --predicate 'process == "donotdisturbd" AND eventMessage CONTAINS "Event was resolved"' \
            | grep -iF "$BUNDLE" | tail -1)
  if [ -n "$LOGLINE" ]; then
    case "$LOGLINE" in
      *"outcome: suppressed"*) OUTCOME=suppressed ;;
      *"outcome: "*)           OUTCOME=delivered ;;
    esac
    # "reason: display shared>" 형태에서 이유만 뽑는다 (마지막 reason= 최종 판정)
    REASON=$(printf '%s' "$LOGLINE" | sed -n 's/.*outcome: [a-z]*; reason: \([^>]*\)>.*/\1/p' | tail -1)
  fi
fi
emit "suppress_outcome=$OUTCOME"
[ -n "$REASON" ] && emit "suppress_reason=$REASON"

# ── 3. 알림센터 DB: 이번 알림이 표시됐는지 + 과거에 표시된 적이 있는지 ────
# presented=1 이력이 하나라도 있으면 알림 권한 자체는 허용된 상태다 —
# "권한 문제"와 "환경(공유/집중 모드) 문제"를 가르는 결정적 구분선.
DB="$HOME/Library/Group Containers/group.com.apple.usernoted/db2/db"
PRESENTED=unknown
EVER=unknown
if [ -r "$DB" ] && command -v sqlite3 >/dev/null 2>&1; then
  q() { sqlite3 -readonly "$DB" "$1" 2>/dev/null; }
  # LIKE는 ASCII 대소문자를 무시한다 — 앱마다 표기가 달라 `=`로 맞추면 놓친다
  LAST=$(q "SELECT presented FROM record r JOIN app a ON r.app_id=a.app_id WHERE a.identifier LIKE '$BUNDLE' ORDER BY delivered_date DESC LIMIT 1;")
  case "$LAST" in
    1) PRESENTED=yes ;;
    0) PRESENTED=no ;;
  esac
  ANY=$(q "SELECT count(*) FROM record r JOIN app a ON r.app_id=a.app_id WHERE a.identifier LIKE '$BUNDLE' AND presented=1;")
  case "$ANY" in
    ''|*[!0-9]*) ;;
    0) EVER=no ;;
    *) EVER=yes ;;
  esac
fi
emit "presented=$PRESENTED"
emit "ever_presented=$EVER"

# ── 4. 설정 정황 (로그·DB를 못 읽는 환경용 폴백 + 조치 안내 근거) ─────────
FOCUS=unknown
MIRRORPREF=unknown
if [ -n "$PYBIN" ]; then
  FOCUS=$("$PYBIN" - <<'PY' 2>/dev/null || echo unknown
import json, os
p = os.path.expanduser("~/Library/DoNotDisturb/DB/Assertions.json")
try:
    recs = json.load(open(p))["data"][0].get("assertionRecords", [])
except Exception:
    print("unknown"); raise SystemExit
if not recs:
    print("none"); raise SystemExit
for r in recs:
    d = r.get("assertionDetails", {}) or {}
    m = d.get("assertionDetailsModeIdentifier")
    if m:
        print(m); raise SystemExit
print("active")
PY
)
  MIRRORPREF=$("$PYBIN" - <<'PY' 2>/dev/null || echo unknown
import plistlib, os
p = os.path.expanduser("~/Library/Group Containers/group.com.apple.usernoted/"
                       "Library/Preferences/group.com.apple.usernoted.plist")
try:
    inner = plistlib.loads(plistlib.load(open(p, "rb"))["dnd_prefs"])
    print(1 if inner.get("dndMirrored") else 0)
except Exception:
    print("unknown")
PY
)
fi
[ -z "$FOCUS" ] && FOCUS=unknown
[ -z "$MIRRORPREF" ] && MIRRORPREF=unknown
emit "focus_active=$FOCUS"
emit "dnd_mirrored=$MIRRORPREF"

# ── 5. 판정 ───────────────────────────────────────────────────────────────
# 근거가 강한 순서로 내려간다. 이유를 특정하지 못하면 UNKNOWN으로 남기고
# 정황(focus/dnd_mirrored)을 그대로 넘겨 호출자가 후보를 제시하게 한다.
VERDICT=UNVERIFIABLE
if [ "$FIRED" != "ok" ]; then
  VERDICT=NO_NOTIFIER
elif [ "$OUTCOME" = suppressed ]; then
  case "$REASON" in
    *shared*|*mirror*|*Mirror*) VERDICT=SUPPRESSED_SHARING ;;
    *sleep*|*Sleep*)            VERDICT=SUPPRESSED_DISPLAY_SLEEP ;;
    *lock*|*Lock*)              VERDICT=SUPPRESSED_SCREEN_LOCK ;;
    *)
      if [ "$FOCUS" != none ] && [ "$FOCUS" != unknown ]; then
        VERDICT=SUPPRESSED_FOCUS
      else
        VERDICT=SUPPRESSED_OTHER
      fi
      ;;
  esac
elif [ "$PRESENTED" = yes ] || [ "$OUTCOME" = delivered ]; then
  VERDICT=OK
elif [ "$PRESENTED" = no ]; then
  if [ "$EVER" = no ]; then
    VERDICT=PERMISSION          # 한 번도 표시된 적 없음 → 알림 권한 미허용 쪽
  elif [ "$FOCUS" != none ] && [ "$FOCUS" != unknown ]; then
    VERDICT=SUPPRESSED_FOCUS
  else
    VERDICT=SUPPRESSED_OTHER
  fi
fi

echo "verdict=$VERDICT"
exit 0
