---
name: handoff
description: 세션 마무리 — 이번 세션의 작업을 Osmosis 팀 메모리에 기록하고 STATUS.md를 갱신한다. 사용자가 "/handoff", "세션 정리", "인수인계", "마무리 기록"이라고 할 때 사용.
allowed-tools: Bash(git *), Bash(ls *), Bash(grep *), Bash(rg *), Bash(date *), Read, Write, Glob, Grep
---

# /handoff — 세션 인수인계 기록

이번 세션에서 한 일을 팀 메모리에 기록한다. 목적: 팀원(과 그들의 Claude)이
다음 세션 시작 시 "무엇이 어떤 상태인지"를 정확히 알게 하는 것.

## 절대 원칙

1. **"했다" ≠ "됐다".** 테스트 통과나 실제 실행으로 확인한 것만 `verified`.
   확인 못 했으면 반드시 `unverified`. 낙관 금지. 애매하면 unverified.
2. **기각된 접근은 반드시 기록.** 시도했다가 버린 방법과 그 이유는
   성공 기록보다 귀하다. 이번 세션에서 하나라도 있었다면 절대 생략하지 않는다.
3. **간결하게.** 엔트리 본문은 15줄 이내. 코드/diff는 붙이지 않는다 —
   git에 이미 있다. 커밋 해시나 파일 경로로만 참조한다.
4. **시크릿 금지.** API 키, 토큰, 비밀번호, 내부 호스트명이 들어가면 안 된다.
   쓰기 전에 스스로 검사할 것.

## 절차

### 0. 부트스트랩 (최초 1회 자동)
`.osmosis/` 디렉토리가 없으면 생성한다:
```bash
mkdir -p .osmosis/journal
grep -q '.osmosis/STATUS.md merge=union' .gitattributes 2>/dev/null || echo '.osmosis/STATUS.md merge=union' >> .gitattributes
```

### 1. 세션 회고
현재 대화와 `git status`, `git log --oneline -10`, `git diff --stat HEAD~5 2>/dev/null`을
보고 이번 세션의 작업을 파악한다. 기록할 것:
- 의도했던 것 / 실제 결과 / 검증 여부와 근거
- 내린 결정과 이유 (있다면)
- 기각한 접근과 이유 (있다면)
- 발견한 함정 (있다면)

### 2. 작성자 확인
```bash
AUTHOR=$(git config user.name | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
```
비어 있으면 사용자에게 짧은 핸들을 물어본다.

### 3. 엔트리 파일 생성
경로: `.osmosis/journal/{AUTHOR}/{YYYYMMDD-HHMM}-{slug}.md`
(slug는 작업을 나타내는 짧은 영문 kebab-case. 한 세션에 성격이 다른 작업이
여럿이면 — 예: 구현 1건 + 독립적 결정 1건 — 파일을 나눠도 된다.)

형식 (frontmatter 필드는 전부 필수, 값이 없으면 null):

```markdown
---
id: osm-{YYYYMMDD}-{4자리 랜덤 hex}
author: {AUTHOR}
ts: {ISO8601, 로컬 타임존}
project: {repo 이름}
module: {주로 건드린 코드 경로/모듈, 예: src/table-parser}
type: work | decision | gotcha | rejected
status: verified | unverified | failed | rejected | superseded
verified_by: {테스트 경로 또는 커밋 해시. status가 verified가 아니면 null}
branch: {git branch --show-current}
supersedes: {갱신하는 기존 엔트리 id, 없으면 null}
refs: [{관련 엔트리 id들, 없으면 빈 배열}]
---
## 의도
{한두 줄. 무엇을 하려 했나}

## 결과
{한두 줄. 실제로 무슨 상태가 되었나. unverified/failed라면 무엇이 확인 안 됐는지 명시}

## 기각/함정
{시도했다 버린 접근 → 이유. 밟은 함정. 없으면 이 섹션 생략}
```

기존 결정을 뒤집거나 갱신하는 경우: 이전 엔트리 파일을 열어 status를
`superseded`로 바꾸고, 새 엔트리의 `supersedes`에 그 id를 넣는다.

### 4. STATUS.md 갱신
`.osmosis/STATUS.md`를 다시 생성한다. **2KB 상한 절대 준수** — 넘으면
오래된 완료 항목부터 지운다. 원본은 journal에 있으니 요약본은 잃을 게 없다.

```markdown
# 팀 현황 (자동생성 {날짜})

## 진행 중 / 미검증
- [unverified] {module}: {한 줄 요약} — {author} ({id})
- [failed] ...

## 최근 결정 (최대 5개)
- {한 줄} — {author} ({id})

## ⚠ 주의
- 미검증 3일+ 방치: {건수} — {해당 id들}
- (있다면) 같은 module에 복수 작성자의 열린 엔트리 → 충돌 후보로 명시
```

"진행 중"에는 status가 unverified/failed인 엔트리만 올린다. verified는
결정이 아닌 한 STATUS에서 내린다.

### 4.5 저널 위생 (조건부)
STATUS 갱신 중 **14일 이상 방치된 unverified** 엔트리를 발견하면, 사용자에게
한 줄로 물어본다: "osm-xxxx (모듈명) 2주째 미검증인데, failed로 정리할까요?
아직 진행 중인가요?" — 동의하면 해당 엔트리의 status만 고친다.
이 정리 덕분에 충돌 경고가 양치기 소년이 되지 않는다.

### 5. 커밋
```bash
git add .osmosis/ && git commit -m "osmosis: handoff {AUTHOR} {slug}"
```
push는 사용자에게 확인 후. (feature 브랜치 위라면 그대로 두면 PR 머지 시 따라간다.)

### 6. 사용자에게 보고
생성한 엔트리의 status와 STATUS.md의 ⚠ 항목만 두세 줄로 요약해준다.
길게 설명하지 않는다.
