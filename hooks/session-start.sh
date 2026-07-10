#!/usr/bin/env bash
# Osmosis SessionStart hook — STATUS 주입 + 모듈 충돌 경고. 어떤 실패도 세션을 막지 않는다.
set -u
T0=$(date +%s%N 2>/dev/null); case "$T0" in *N*) T0="";; esac
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
OSM="$ROOT/.osmosis"
[ -d "$OSM" ] || exit 0

ME="$(git config user.name 2>/dev/null | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"
ME_UNSET=0
if [ -z "$ME" ]; then ME="$(whoami)"; ME_UNSET=1; fi

# 매 세션 원격 최신화(최대 3초). 오프라인/대형 repo에서 지연되면 timeout으로 끊고
# 로컬 캐시 기준으로 진행 — 충돌 경고가 살짝 낡을 뿐 세션은 막지 않는다.
command -v timeout >/dev/null 2>&1 && timeout 3 git -C "$ROOT" fetch --quiet 2>/dev/null
BEHIND=$(git -C "$ROOT" rev-list --count HEAD..@{upstream} 2>/dev/null || echo 0)

echo "=== OSMOSIS — 팀의 오아시스 ==="
[ "${BEHIND:-0}" -gt 0 ] && echo "[알림] 원격에 새 커밋 ${BEHIND}건 — STATUS가 구버전일 수 있음. git pull 권장."
[ "$ME_UNSET" = "1" ] && echo "[주의] git user.name 미설정 → 작성자를 '$ME'로 추정. 공용/컨테이너 환경이면 팀원 구분이 안 돼 충돌 경고가 누락될 수 있음. git config user.name 설정 권장."

if [ -f "$OSM/STATUS.md" ]; then
  # 2KB 하드 가드: handoff가 상한을 어겨도 세션 토큰 예산을 지킨다.
  head -n 60 "$OSM/STATUS.md" | head -c 2048
  echo
else
  echo "(STATUS.md 없음 — 첫 /handoff 때 생성됨)"
fi

# 충돌 감지: 다른 작성자의 열린(unverified/failed) 엔트리
# 소스 1: 현재 브랜치 작업트리 (최근 30일)
# 소스 2: 원격의 다른 브랜치들 (최근 30일 내 커밋된 브랜치, 최대 20개)
#         → 머지 전 feature 브랜치의 작업도 보이게 (브랜치 사각지대 제거)
#         주: 소스2는 브랜치 committerdate로만 컷오프하고 엔트리별 mtime 필터는 없다
#         (git show는 mtime이 없음). 브랜치가 30일 내 활성이면 열린 엔트리로 간주.
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
