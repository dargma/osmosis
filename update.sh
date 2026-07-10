#!/usr/bin/env bash
# Osmosis 업데이트 — 항상 안전: 팀 기록(.osmosis/journal)은 절대 건드리지 않음
#   사용법: ./update.sh [프로젝트루트]
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="${1:-$(pwd)}"
OLD=$(cat "$DST/.osmosis/VERSION" 2>/dev/null || echo "-")
cd "$SRC" && git pull --quiet 2>/dev/null || true
NEW=$(cat "$SRC/VERSION")
if [ "$OLD" = "$NEW" ]; then
  echo "✨ 이미 최신입니다 (v$NEW). 할 일 없음."
  exit 0
fi
"$SRC/install.sh" "$DST" > /dev/null
echo "✨ v$OLD → v$NEW 갱신 완료. 기록·설정 전부 보존됨. 재시작도 필요 없음."
