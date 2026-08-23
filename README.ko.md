[English](README.md) | 한국어 | [中文](README.zh.md) | [日本語](README.ja.md) | [Español](README.es.md)

# ddiring

<p align="center">
  <img src="assets/ddiring-hero-01.png" alt="ddiring" width="320">
</p>

> "작업 완료"가 아니라 **어느 세션이** 끝났는지 알려주는 알림.

iTerm, Cursor, 세션 매니저에 걸쳐 클로드코드 세션을 5~10개 띄워놓고 쓰다 보면, 밋밋한 "작업 완료" 배너로는 결국 창을 하나하나 뒤져야 합니다. ddiring(띠링)은 알림 하나로 세 가지에 답합니다: **어느 폴더** 작업인지(제목), 그 세션이 **어느 터미널/앱**에 떠 있는지(부제목), **무슨 작업**을 시켰는지(본문 — 마지막 프롬프트 70자 요약). macOS에서 `terminal-notifier`가 있으면 클릭 시 그 앱으로 바로 점프합니다.

[빠른 시작](#빠른-시작) • [왜 ddiring인가](#왜-ddiring인가) • [작동 방식](#작동-방식) • [주요 기능](#주요-기능) • [명령어](#명령어) • [요구사항](#요구사항)

---

## 빠른 시작

### 1. 마켓플레이스 추가

```
/plugin marketplace add https://github.com/fivetaku/gptaku_plugins.git
```

### 2. 설치

```
/plugin install ddiring
```

### 3. Claude Code 재시작

(훅과 명령어는 재시작 후에 등록됩니다.)

### 4. 사용법

따로 할 일이 없습니다 — 이제 모든 세션이 끝날 때마다 띠링 하고 울립니다:

- **✅ my-app** / *iTerm* / "인증 테스트 플레이키 고치고 CI 재실행" — iTerm의 그 작업이 끝남
- **⏸️ blog** / *Cursor* / "권한 대기 중" — 어떤 세션이 당신을 기다림
- 알림 클릭(macOS + `terminal-notifier`)으로 그 앱에 바로 포커스

클릭-포커스를 쓰려면(선택):

```bash
brew install terminal-notifier
```

## 왜 ddiring인가

멀티세션 작업의 반복되는 미세 고통: *뭔가* 끝났는데, 기본 알림은 뭐가 어디서 끝났는지 말해주지 않습니다. 세션 ID도 답이 아닙니다 — `a3f9c2`를 보고 "Warp에서 돌리던 그 리팩토링"을 떠올릴 수는 없으니까요. ddiring은 사람이 실제로 알아보는 세 가지를 보여줍니다: 폴더 이름, 앱 이름, 그리고 내가 직접 친 마지막 프롬프트.

## 작동 방식

세션이 응답을 마치면 `Stop` 훅이(권한/입력 대기는 `Notification` 훅이 ⏸️로) 발화합니다. 스크립트는:

1. transcript 꼬리를 먼저 200KB, 못 찾으면 최대 2MB까지 읽어 마지막 **진짜** 프롬프트를 추출합니다 — 도구 결과·시스템 태그·인터럽트 표기는 건너뜁니다;
2. 프로세스 환경으로 호스트 앱을 식별합니다 — macOS는 `__CFBundleIdentifier`, Windows는 env 판별(`TERM_PROGRAM` → `WT_SESSION` → `ConEmuPID`, 상속 오탐을 피해 안쪽 변수 우선);
3. 알림을 쏩니다: macOS는 `terminal-notifier`(클릭 가능) 또는 `osascript`, Windows는 PowerShell 5.1 WinRT 토스트.

훅이 스크립트를 파일로 실행하기 때문에, 매핑 수정은 **이미 떠 있는 세션에도** 즉시 반영됩니다 — 재시작 불필요.

## 주요 기능

- **30+종 앱 매핑, 리서치 실측 검증** (로컬 `Info.plist`·Homebrew cask 정의·공식 저장소 설정): Terminal, iTerm2, VS Code(+Insiders), VSCodium, Cursor, Windsurf(Devin), Antigravity, Warp, Ghostty, Alacritty, kitty, WezTerm, Tabby, Hyper, Zed, JetBrains, Rio, Termius, Wave, Positron, Kiro, Trae, Xcode — 그리고 클로드코드 세션 매니저: Paseo, cmux, Conductor, Orca, Sculptor, Superset, Crystal, Waku, Jean, Fletch, Constellagent, GraphCode, Clave, Xum.
- **tmux/Zellij 패스스루** — 별도 감지 로직 없이 상속된 호스트 환경변수로 표시합니다(시작한 앱과 다른 앱에서 attach한 tmux 서버는 원래 호스트로 표시될 수 있음).
- **기본이 조용함** — 볼륨 0.2의 은은한 완료음. env로 음소거/조정.
- **Windows 지원(실험)** — Git Bash 훅 경로에서 PowerShell 토스트. 토스트 백엔드 자체는 추가 설치가 없지만 프롬프트 추출엔 Python 3가 필요합니다(없으면 고정 문구). 표시 전용, 실기 검증 전 — 제보 환영.
- **모르는 앱도 우아하게** — `TERM_PROGRAM`이나 번들 ID를 그대로 표시. 매핑 추가는 한 줄.

## 명령어

| 명령어 | 동작 |
|---|---|
| `/ddiring` | 현재 상태(환경변수 설정, `terminal-notifier` 유무, 감지된 터미널) |
| `/ddiring test` | 이 세션의 transcript로 테스트 알림 발사 |
| `/ddiring 볼륨 0.1` / `음소거` | 볼륨 변경 / 음소거 |

### 설정

Claude 설정 파일의 `"env"` 블록에 넣으면 새로 시작하는 세션부터 적용됩니다:

| 변수 | 기본값 | 의미 |
|---|---|---|
| `DDIRING_SILENT` | `0` | `1` = 소리 없이 배너만 (macOS) |
| `DDIRING_VOLUME` | `0.2` | 0.0~1.0 (macOS) |
| `DDIRING_SOUND` | `Glass.aiff` | `/System/Library/Sounds/*.aiff` 아무거나 (macOS) |
| `DDIRING_HIDE_BODY` | `0` | `1` = 본문 숨김 (잠금화면·화면공유 프라이버시) |

> 참고: 알림 본문은 OS 알림 센터와 잠금 화면에 남습니다 — 민감한 프롬프트를 다루면 `DDIRING_HIDE_BODY=1`을 켜세요. `/ddiring` 첫 실행 시 gptaku 플러그인 공통 업데이트 알림 훅도 설치됩니다.

## 요구사항

- macOS(정식 지원) 또는 Windows + Git Bash(실험). 그 외 OS에서는 조용히 아무것도 안 합니다
- `python3` (macOS 기본 탑재) — transcript 파싱용
- 선택: 클릭-포커스용 `terminal-notifier` (macOS)

## 라이선스

[MIT](./LICENSE) — [DISCLAIMER.md](./DISCLAIMER.md)도 참고하세요.
