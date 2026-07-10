#!/usr/bin/env bash
# Osmosis 제거. 팀 기록은 기본 보존, 전체 삭제는 --purge
# 사용법: uninstall.sh [--purge] [프로젝트루트]  (install.sh와 동일하게 경로는 위치인자)
set -e
PURGE=0; DST=""
for a in "$@"; do
  case "$a" in
    --purge) PURGE=1 ;;
    *) DST="$a" ;;
  esac
done
cd "${DST:-$(pwd)}"
rm -rf .claude/skills/handoff .claude/skills/catchup
rm -f .claude/hooks/osmosis-session-start.sh
python3 - << 'PY'
import json, os
p = ".claude/settings.json"
if os.path.exists(p):
    s = json.load(open(p))
    ss = s.get("hooks", {}).get("SessionStart", [])
    s["hooks"]["SessionStart"] = [e for e in ss if not any(
        "osmosis" in h.get("command","") for h in e.get("hooks", []))]
    json.dump(s, open(p, "w"), indent=2, ensure_ascii=False)
PY
if [ "$PURGE" = "1" ]; then rm -rf .osmosis; fi
# 잔여물 검증
LEFT=$( { ls -d .claude/skills/handoff .claude/skills/catchup .claude/hooks/osmosis-* 2>/dev/null; \
          grep -l osmosis .claude/settings.json 2>/dev/null; } | wc -l )
if [ "$LEFT" -eq 0 ]; then
  if [ "$PURGE" = "1" ]; then
    echo "🧼 완전 삭제 검증 완료 — 흔적: 0개. 설치 전과 동일합니다."
  else
    echo "🧼 제거 검증 완료 — 도구 흔적: 0개. (팀 기록 .osmosis/ 만 보존, --purge로 전체 삭제)"
  fi
else
  echo "⚠ 잔여물 $LEFT개 발견 — 수동 확인 필요"
fi
