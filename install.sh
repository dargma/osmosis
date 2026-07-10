#!/usr/bin/env bash
# Osmosis 설치 — 대상 프로젝트 루트에서 실행하거나, 경로를 인자로 준다.
#   사용법: /path/to/osmosis/install.sh [프로젝트루트]
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="${1:-$(pwd)}"
cd "$DST"
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "❌ git repo가 아닙니다: $DST"; exit 1; }

echo "🧪 Osmosis 설치 → $DST"

mkdir -p .claude/commands .claude/hooks .osmosis/journal
cp "$SRC/commands/handoff.md"      .claude/commands/handoff.md
cp "$SRC/commands/osmosis.md"      .claude/commands/osmosis.md
cp "$SRC/hooks/session-start.sh"   .claude/hooks/osmosis-session-start.sh
chmod +x .claude/hooks/osmosis-session-start.sh
[ -f .osmosis/STATUS.md ] || cp "$SRC/memory/STATUS.md" .osmosis/STATUS.md
cp "$SRC/VERSION" .osmosis/VERSION 2>/dev/null || true

# settings.json에 훅 병합 (python3 사용, 기존 설정 보존)
python3 - << 'PY'
import json, os
p = ".claude/settings.json"
s = json.load(open(p)) if os.path.exists(p) else {}
hooks = s.setdefault("hooks", {}).setdefault("SessionStart", [])
cmd = "bash .claude/hooks/osmosis-session-start.sh"
if not any(cmd == h.get("command") for e in hooks for h in e.get("hooks", [])):
    hooks.append({"hooks": [{"type": "command", "command": cmd}]})
json.dump(s, open(p, "w"), indent=2, ensure_ascii=False)
print("  ✓ .claude/settings.json 훅 등록")
PY

grep -q '.osmosis/STATUS.md merge=union' .gitattributes 2>/dev/null || \
  echo '.osmosis/STATUS.md merge=union' >> .gitattributes

echo "  ✓ 파일 배치 완료"
echo ""
echo "마지막 한 걸음 (팀 전체 적용):"
echo "  git add .claude .osmosis .gitattributes && git commit -m 'osmosis: install' && git push"
echo ""
echo "끝. 이제 세션 끝날 때 /handoff 만 기억하세요."
