---
description: 세션 중 Osmosis 팀 현황·열린 작업을 다시 조회한다 (인자로 모듈/키워드 필터)
allowed-tools: Bash(cat *), Bash(ls *), Bash(grep *), Bash(rg *), Bash(git *), Read, Glob, Grep
---

# /osmosis — 팀 현황 다시 보기

세션 시작 시 훅이 이미 한 번 주입했지만, 작업 도중 다시 확인하고 싶을 때 쓴다.
읽기 전용 — 아무것도 쓰지 않는다.

인자(`$ARGUMENTS`)가 있으면 **그 모듈/키워드로 필터**한다. 없으면 전체 요약을 보여준다.

## 절차

### 0. .osmosis 존재 확인
```bash
ls .osmosis/STATUS.md 2>/dev/null || echo "NO_OSMOSIS"
```
없으면 "아직 Osmosis 기록이 없습니다. 세션 끝에 /handoff 로 첫 기록을 남기세요."
한 줄만 답하고 종료.

### 1. 현황 요약 출력
`.osmosis/STATUS.md`를 읽어 그대로 보여준다 (2KB 요약본).

### 2. 열린 작업 목록
전체 저널에서 아직 열린(unverified/failed) 엔트리를 훑는다:
```bash
grep -rl -E "^status:[[:space:]]*(unverified|failed)" .osmosis/journal 2>/dev/null
```
각 파일의 frontmatter(module·author·status·id)와 `## 결과` 한 줄을 뽑아
아래 형식으로 정리한다:
```
- [status] module : 한 줄 요약 — author (id)   → .osmosis/journal/…/파일.md
```

### 3. 필터 (인자가 있을 때)
`$ARGUMENTS`가 주어졌으면, 2단계 결과를 **module 또는 본문에 그 문자열이 포함된 것만** 남긴다.
예: `/osmosis table-parser` → table-parser 관련 열린 작업만.
매칭 0건이면 "해당 조건의 열린 작업 없음 — 안전"이라고 답한다.

### 4. 상세를 원하면
사용자가 특정 id/모듈을 더 보고 싶어 하면, 해당 저널 파일을 Read로 열어
`## 의도 / 결과 / 기각·함정`을 요약해준다. 시키기 전엔 파일 전문을 쏟지 않는다.

## 출력 원칙
- 간결하게. STATUS 요약 + 열린 작업 목록이면 충분하다.
- 열린 작업이 없으면 "열린 작업 없음. 팀 현황 깨끗함" 한 줄로 끝낸다.
- 절대 파일을 수정하지 않는다. 조회 전용이다.
