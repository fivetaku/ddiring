# ddiring — Codex 메모

- Codex에서도 `Stop` 훅 알림은 그대로 동작한다(2026-11-23 실측). 훅 입력의 `transcript_path`가 Codex rollout(jsonl, `response_item` 레코드)이면 `notify.sh`가 그 형식으로 마지막 사용자 프롬프트를 읽어 본문에 쓴다. Claude Code transcript 형식도 그대로 읽는다.
- `Notification` 이벤트는 Codex가 지원하지 않는다. Codex에서는 권한·입력 대기(⏸️) 알림이 오지 않으며, 대응 구현은 하지 않는다.
- `/ddiring` 명령의 `Skill` 호출은 Codex에 없다. `skills/ddiring-config/SKILL.md`를 직접 열어 그 절차를 따른다. 이 스킬은 선택지 질문을 하지 않는다.
- 발화 없이 문구만 보려면 `DDIRING_DRYRUN=1`로 `hooks/scripts/notify.sh stop`에 훅 입력 JSON을 넘긴다.
- `${CLAUDE_PLUGIN_ROOT}`는 Codex에서 치환되지 않는다. 이 플러그인 루트(이 파일에서 한 단계 위 폴더)로 바꿔 읽는다.
