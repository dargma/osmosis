#!/usr/bin/env bash
# Osmosis SessionStart hook — STATUS 주입 + 모듈 충돌 경고. 어떤 실패도 세션을 막지 않는다.
set -u
T0=$(date +%s%N 2>/dev/null); case "$T0" in *N*) T0="";; esac
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
OSM="$ROOT/.osmosis"
[ -d "$OSM" ] || exit 0

ME="$(git config user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"
[ -n "$ME" ] || ME="$(whoami)"

command -v timeout >/dev/null 2>&1 && timeout 3 git -C "$ROOT" fetch --quiet 2>/dev/null
BEHIND=$(git -C "$ROOT" rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)

echo "=== OSMOSIS — 팀의 오아시스 ==="
[ "${BEHIND:-0}" -gt 0 ] && echo "[알림] 원격에 새 커밋 ${BEHIND}건 — STATUS가 구버전일 수 있음. git pull 권장."

if [ -f "$OSM/STATUS.md" ]; then
  head -n 60 "$OSM/STATUS.md"
else
  echo "(STATUS.md 없음 — 첫 /handoff 때 생성됨)"
fi

# 충돌 감지: 다른 작성자의 열린(unverified/failed) 엔트리
# 소스 1: 현재 브랜치 작업트리 (최근 30일)
# 소스 2: 원격의 다른 브랜치들 (최근 30일 내 커밋된 브랜치, 최대 20개)
#         → 머지 전 feature 브랜치의 작업도 보이게 (브랜치 사각지대 제거)
scan_entry() {  # stdin: 엔트리 내용 → "module|author|id" (열린 상태일 때만)
  awk -v me="$ME" '
    /^status:[[:space:]]*(unverified|failed)[[:space:]]*$/ {open=1}
    /^author:/ {a=$2} /^module:/ {m=$2} /^id:/ {i=$2}
    END { if (open && m != "" && a != me) print m"|"a"|"i }'
}
if [ -d "$OSM/journal" ] || git -C "$ROOT" rev-parse --verify -q origin/HEAD >/dev/null 2>&1; then
  COLLISIONS=$(
    { find "$OSM/journal" -name '*.md' -mtime -30 2>/dev/null |
        while read -r f; do scan_entry < "$f"; done
      CUTOFF=$(( $(date +%s) - 30*86400 ))
      git -C "$ROOT" for-each-ref --sort=-committerdate           --format='%(refname:short) %(committerdate:unix)' refs/remotes/origin 2>/dev/null |
        grep -v 'origin/HEAD' | head -20 |
        while read -r ref cdate; do
          [ "${cdate:-0}" -ge "$CUTOFF" ] || continue
          git -C "$ROOT" ls-tree -r --name-only "$ref" -- .osmosis/journal 2>/dev/null |
            while read -r path; do
              git -C "$ROOT" show "$ref:$path" 2>/dev/null | scan_entry
            done
        done
    } | sort -u
  )
  if [ -n "$COLLISIONS" ]; then
    N=$(echo "$COLLISIONS" | wc -l)
    echo ""
    echo "[열린 작업 — 착수 전 확인]"
    echo "$COLLISIONS" | head -8 | while IFS='|' read -r m a i; do
      echo "- $m : $a 의 미검증/실패 엔트리 ($i)"
    done
    [ "$N" -gt 8 ] && echo "  …외 $((N-8))건 (grep 'status: unverified' .osmosis/journal -r 로 전체 확인)"
    echo "→ 이 모듈을 건드릴 거면, 해당 엔트리를 먼저 읽고 중복/충돌 여부를 사용자에게 알릴 것."
  fi
fi

if [ -n "$T0" ]; then
  echo "=== /OSMOSIS ⚡ $(( ($(date +%s%N)-T0)/1000000 ))ms ==="
else
  echo "=== /OSMOSIS ==="
fi
exit 0
