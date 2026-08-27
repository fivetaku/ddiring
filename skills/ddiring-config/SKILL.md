---
name: ddiring-config
description: This skill should be used when the user asks to "띠링 설정", "알림 볼륨 바꿔줘", "알림 소리 꺼줘", "완료 알림 테스트", "ddiring config", reports that the terminal name in a ddiring notification is wrong, or reports that notifications do not appear ("알림이 안 떠", "소리만 나고 배너가 없어", "notifications not showing"). Configures the ddiring completion-notification hook (volume, sound, mute, terminal mapping) and diagnoses notifications that fire but are never displayed.
---

# ddiring 설정

알림 스크립트: `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/notify.sh`
동작: Stop(작업 완료)·Notification(권한/입력 대기) 이벤트마다 알림을 띄운다.
- 제목 `✅ 폴더명` · 부제목 `터미널/앱 이름` · 본문: Stop이면 `마지막 사용자 프롬프트 70자 요약`, Notification이면 `이벤트 메시지 70자 요약`
- macOS: `terminal-notifier`가 있으면 클릭 시 해당 앱으로 포커스 이동, 없으면 osascript 배너로 폴백.
- Windows(Git Bash, 실험): PowerShell 5.1 WinRT 토스트. 표시 전용(클릭 동작 없음), 소리 옵션 미적용.
- 그 외 OS: 조용히 종료.

## 설정 방법 (환경변수)

사용자 Claude 설정 파일(settings.json)의 `"env"` 블록에 넣으면 모든 세션에 적용된다:

| 변수 | 기본값 | 의미 |
|---|---|---|
| `DDIRING_SILENT` | `0` | `1`이면 소리 끔(배너만) — macOS |
| `DDIRING_VOLUME` | `0.2` | 0.0~1.0 — macOS |
| `DDIRING_SOUND` | `/System/Library/Sounds/Glass.aiff` | 다른 시스템 사운드로 교체 가능 — macOS |
| `DDIRING_HIDE_BODY` | `0` | `1`이면 본문 숨김(잠금화면·화면공유 프라이버시) |
| `DDIRING_DEBUG` | `0` | `1`이면 실패 사유를 `${TMPDIR:-/tmp}/ddiring.log`에 기록 |

주의: settings.json의 env 변경은 **새로 시작/재개하는 세션부터** 적용된다. 이미 떠 있는 세션은 재시작 필요. (훅 스크립트 자체의 수정은 파일 경유 실행이라 떠 있는 세션에도 즉시 반영된다.)

## 테스트

```bash
echo "{\"cwd\":\"$PWD\",\"session_id\":\"test\",\"transcript_path\":\"\"}" \
  | bash "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/notify.sh" stop
```

이 테스트는 transcript_path가 비어 있어 본문이 "작업 완료 (Done)"로 뜬다 — 알림 전달 경로 검증용. 실제 프롬프트 본문까지 확인하려면 transcript_path에 실제 세션 jsonl 경로를 넣어야 한다.

## 알림이 안 뜰 때 — 진단 (doctor)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/setup/doctor.sh"
```

**"알림이 안 떠", "소리만 나" 류의 호소에는 설정을 건드리기 전에 이걸 먼저 돌린다.**
발사 성공 여부만 보는 위의 테스트와 달리, 테스트 알림을 한 번 쏜 뒤 **macOS가 실제로 화면에
표시했는지**와 표시하지 않았다면 그 이유를 OS 근거(donotdisturbd 판정 로그 → 알림센터 DB의
presented 플래그 → 설정 파일 순)로 판정한다. 약 4초 걸린다.

출력의 `verdict=` 한 줄로 분기해 **사용자 언어로** 원인과 조치를 설명한다:

| verdict | 의미 | 조치 |
|---|---|---|
| `OK` | 정상 표시됨 | 없음. 알림이 안 보였다면 표시 위치·기간 문제이니 시스템 설정 > 알림에서 스타일을 '배너' 대신 '알림'으로 바꾸도록 안내 |
| `SUPPRESSED_SHARING` | 화면 공유·미러링 중이라 OS가 전 앱 알림을 억제 중 | ① 시스템 설정 > 알림 > **"디스플레이를 미러링하거나 공유할 때 알림 허용"을 켠다**(가장 확실) ② 또는 화면 공유·미러링을 끝낸다. 화면 녹화·원격 데스크톱(Chrome 원격 데스크톱 등)·화상회의 공유도 여기 해당 |
| `SUPPRESSED_FOCUS` | 집중 모드가 켜져 있음 (`focus_active=`에 모드 ID) | 집중 모드를 끄거나, 시스템 설정 > 집중 모드 > 해당 모드 > 허용된 알림에 알리미 앱을 추가 |
| `SUPPRESSED_DISPLAY_SLEEP` | 디스플레이가 잠들어 있는 동안 억제 | 시스템 설정 > 알림 > "디스플레이가 잠자기 상태일 때 알림 허용"을 켠다 |
| `SUPPRESSED_SCREEN_LOCK` | 화면 잠금 중 억제 | 시스템 설정 > 알림 > "화면이 잠겨 있을 때 알림 허용"을 켠다 |
| `PERMISSION` | 한 번도 표시된 적 없음 → 알림 권한 미허용 | 시스템 설정 > 알림에서 `bundle=`에 나온 앱(보통 terminal-notifier)의 알림을 허용하고 스타일을 배너/알림으로 설정 |
| `SUPPRESSED_OTHER` | 억제됐으나 이유 특정 실패 | `suppress_reason=`·`focus_active=`·`dnd_mirrored=` 값을 그대로 보여주고 위 후보들을 점검하도록 안내 |
| `NO_NOTIFIER` | 알림 발사 자체가 실패 | `brew install terminal-notifier` 설치 안내 |
| `UNVERIFIABLE` | 표시 여부를 확인할 근거를 못 읽음 | 터미널에 전체 디스크 접근 권한이 없으면 로그·DB를 못 읽는다. 사용자에게 배너가 실제로 보였는지 직접 확인받는다 |
| `UNSUPPORTED_OS` | macOS 아님 | Windows는 진단 미지원(표시 전용 실험 지원) |

판정 근거가 필요하면 나머지 key=value 라인을 읽는다 — `presented`(이번 알림 표시 여부),
`ever_presented`(과거에 표시된 적 있는지 = 권한 정상 여부), `suppress_reason`(OS가 남긴 억제 사유),
`focus_active`, `dnd_mirrored`(미러링·공유 중 방해금지 설정값).

첫 실행 진단 결과는 `~/.gptaku-setup/ddiring.doctor.txt`에 남는다.

## 터미널 이름이 틀리게 나올 때

notify.sh의 `detect_app_mac()`(macOS) / `detect_app_win()`(Windows) 함수가 매핑 테이블이다.

- macOS: 사용자에게 `echo $__CFBundleIdentifier`를 실행하게 해 실제 번들 ID를 확인한 뒤 해당 case에 한 줄 추가한다.
- Windows: `env | grep -iE 'TERM_PROGRAM|WT_|ConEmu'` 출력으로 판별 변수를 확인한다.

지원 중 (2026-08-23 리서치 실측 기반, 30+종): Terminal, iTerm2, VS Code(+Insiders), VSCodium, Cursor, Windsurf(Devin), Antigravity, Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains 계열, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode + 세션 매니저(Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum). 매핑에 없으면 `TERM_PROGRAM` 값 또는 번들 ID를 그대로 표시한다(동작은 정상). tmux/Zellij 세션은 호스트 터미널로 표시된다(정상 — 멀티플렉서는 앱 번들이 없음).

## 프라이버시

알림 본문(프롬프트 요약)은 OS 알림 센터와 잠금 화면에 남는다. 민감한 내용을 다루는 사용자에게는 `DDIRING_HIDE_BODY=1`을 안내한다.

## 제약

- 클릭-포커스 기능은 macOS + `brew install terminal-notifier` 필요. 없어도 배너 알림은 뜬다.
- Windows는 실험 지원: Git Bash 훅 경로에서만 검증 설계됐고 실기 검증 전. 문제 보고 환영.
- Windows에서 저장소를 클론해 쓸 때 `.sh` 훅이 CRLF로 체크아웃되면 실행이 깨진다 — 이 저장소는 `.gitattributes`로 LF를 강제한다.
