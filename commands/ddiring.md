---
description: 띠링 알림 설정·테스트 (볼륨/사운드/음소거/터미널 매핑 확인)
---

<!-- first-run setup: idempotent, non-blocking, self-skips after first run -->
**Step 0 — run once at the very start, before anything else:** run `bash "${CLAUDE_PLUGIN_ROOT}/setup/setup.sh" ask`. The output may contain two independent lines — handle each if present (first run only; it takes a few seconds because it fires one real test notification).

If a line starts with `DDIRING_DOCTOR`, the first-run self-check found that notifications fire but do **not** actually appear on screen. Report it **in the user's language** and give the fix for that verdict (see the skill's 진단 표), then continue. Do not claim ddiring is broken — the notification itself was sent successfully.

If a line starts with `STAR_ASK`, immediately call the **AskUserQuestion** tool once, with the question and options phrased **in the user's language**: prefer the current conversation's language if it is evident; otherwise fall back to the language code that follows `STAR_ASK` in the output (`ko`→Korean, `ja`→Japanese, `en`→English). Never default to Korean blindly.
- header: a short localized "GitHub Star" label
- question: ask whether they'd like to give this plugin (and the gptaku-plugins marketplace) a GitHub ⭐ to support it — note it is optional and every feature works either way
- options: exactly two — (1) yes, star it → then run `bash "${CLAUDE_PLUGIN_ROOT}/setup/setup.sh" star yes`; (2) no thanks → then run `bash "${CLAUDE_PLUGIN_ROOT}/setup/setup.sh" star no`

If the output is empty, just continue silently. (AskUserQuestion must NOT be in frontmatter allowed-tools.) Do not narrate beyond the question itself.

# /ddiring — 알림 설정 라우터

사용자의 요청(`$ARGUMENTS`)에 따라 분기한다. 인자가 없으면 현재 상태를 보여준다.

먼저 스킬을 로드하라: `ddiring-config` 스킬 (Skill 도구로 `ddiring:ddiring-config` 호출).

- **상태/status**: 현재 설정(환경변수 DDIRING_SILENT/DDIRING_VOLUME/DDIRING_SOUND), terminal-notifier 설치 여부, 이 세션의 터미널 감지 결과(`__CFBundleIdentifier`)를 보여준다.
- **테스트/test**: 훅 스크립트를 샘플 JSON으로 직접 실행해 알림 전달 경로를 검증한다(본문은 고정 문구). 실제 프롬프트 본문까지 보려면 `~/.claude/projects/` 아래 현재 프로젝트의 최신 세션 jsonl 경로를 transcript_path로 넣어 실행한다.
- **진단/doctor ("알림이 안 떠", "소리만 나", "배너가 안 보여")**: `bash "${CLAUDE_PLUGIN_ROOT}/setup/doctor.sh"`를 실행한다. 발사만이 아니라 **실제 화면 표시 여부**까지 OS 근거로 판정한다. 출력의 `verdict=`를 스킬의 진단 표에서 찾아 원인과 조치를 사용자 언어로 설명한다. **알림이 안 뜬다는 호소에는 이 진단을 먼저 돌려라** — 설정을 바꾸기 전에 원인부터 특정한다.
- **볼륨 N / 음소거 / 소리 변경**: 스킬의 설정 절차를 따라 환경변수를 안내하거나 사용자 설정 파일 `env` 블록에 반영한다.
- **터미널이 이상하게 표시됨**: 스킬의 매핑 추가 절차를 따른다.
