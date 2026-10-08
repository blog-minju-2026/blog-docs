# Quickstart: 한채 로컬 실행과 P1 확인

**Feature**: `001-blog` | **Date**: 2026-10-08 | **Plan**: [plan.md](./plan.md)

구현이 끝난 뒤 내 컴퓨터에서 한채를 띄우고, P1 사용자 이야기 1~6이 동작하는지 확인하는 순서다. 명령과 파일 이름은 [plan.md](./plan.md)의 프로젝트 구조를 기준으로 한다. `/speckit.implement` 중에 바뀌면 이 문서도 함께 고친다.

## 1. 준비물

| 도구 | 버전 | 용도 |
| --- | --- | --- |
| Python | 3.13 | 서버 |
| uv | 최신 | 파이썬 패키지·가상환경 관리 |
| Docker Desktop | 최신 | MySQL 8.4, Mailpit(가짜 메일함) 실행 |
| Git | | |

## 2. 처음 한 번 설정

```bash
git clone https://github.com/blog-minju-2026/blog-docs.git
cd blog-docs

cp .env.example .env            # 비밀 값 파일. 커밋하지 않는다. 소셜 키는 4절, 나중에 채워도 됨
docker compose up -d db mailpit # MySQL(3306), Mailpit(웹 8025, SMTP 1025)

uv sync                         # 의존성 설치
uv run python manage.py migrate # 테이블 생성 + 주제 10개 입력
uv run python manage.py createcachetable   # 로그인 실패 횟수용 DB 캐시
uv run python manage.py create_service_admin admin@example.com  # 서비스 관리자 1명 (ADMIN-01)
```

## 3. 실행

```bash
uv run python manage.py runserver
```

- 사이트: <http://localhost:8000>
- 가입 인증·비밀번호 재설정 메일: <http://localhost:8025> (Mailpit)
- 정각 순위 집계를 바로 돌려 보기(P2): `uv run python manage.py compute_rankings --now`

## 4. 소셜 로그인 키 (선택)

이메일 가입만으로도 P1 확인은 모두 된다. 소셜 로그인을 확인하려면 제공사마다 앱을 만들고 `.env`에 키를 넣는다.

| 제공사 | 만드는 곳 | 콜백 주소(개발) | `.env` 키 |
| --- | --- | --- | --- |
| 카카오 | Kakao Developers | `http://localhost:8000/accounts/kakao/login/callback/` | `KAKAO_CLIENT_ID`, `KAKAO_SECRET` |
| 구글 | Google Cloud Console (OAuth 클라이언트) | `http://localhost:8000/accounts/google/login/callback/` | `GOOGLE_CLIENT_ID`, `GOOGLE_SECRET` |
| 네이버 | NAVER Developers | `http://localhost:8000/accounts/naver/login/callback/` | `NAVER_CLIENT_ID`, `NAVER_SECRET` |

카카오 이메일 동의와 네이버 검수 조건은 [research.md](./research.md) 4절을 본다.

## 5. 자동 테스트 (원칙 V)

```bash
uv run ruff check .
uv run pytest                               # 단위·통합·권한표 (MySQL 테스트 DB)
uv run pytest --req POST-04a                # 한 요구사항의 테스트만
uv run playwright install chromium webkit   # 처음 한 번
uv run pytest tests/e2e --browser chromium --browser webkit  # P1 한 바퀴, 360px
```

병합 전에 위 명령이 모두 통과해야 한다.

## 6. P1 손으로 확인하기

브라우저 창 두 개(일반 창 = 회원 A, 시크릿 창 = 회원 B 또는 비회원)를 쓴다. 각 단계 끝 괄호는 spec 수용 시나리오(`US1-3` = 이야기 1의 3번)와 요구사항 ID다.

### 이야기 1. 가입·로그인과 블로그 개설

1. 시크릿 창에서 **글쓰기** → 로그인 화면으로 간다 (COM-02).
2. **이메일로 가입**: 비밀번호 7자, 닉네임 1자, 동의 칸 하나를 비운 채 제출 → 세 칸에 각각 이유가 나오고 입력은 남아 있다 (AUTH-01a, AUTH-01e, AUTH-01f, COM-02a). 고쳐서 가입한다.
3. Mailpit에서 인증 메일 링크를 연다 → 가입 완료 (US1-3).
4. 다른 창에서 같은 닉네임을 대소문자만 바꿔 가입 → 겹친다고 나온다 (AUTH-01f).
5. 틀린 비밀번호로 로그인 → "이메일 또는 비밀번호가 맞지 않습니다" 하나만 나온다 (US1-4). 5번 연달아 틀리면 잠시 막혔다는 안내가 나온다 (AUTH-01g).
6. **비밀번호 재설정** 요청 → Mailpit 링크에서 새 비밀번호 → 그 비밀번호로 로그인된다. 같은 링크를 다시 열면 쓸 수 없다고 나온다 (US1-5).
7. 로그인 후 **글쓰기** → 블로그 개설 화면. "주소는 개설 후 바꿀 수 없다" 안내가 보인다 (US1-6, US1-8).
8. 주소에 `admin`, `abc`, `-abcd`, `ABCD`를 차례로 넣는다 → 각각 예약어·길이·하이픈·형식 이유가 나온다 (US1-7).
9. `minju-a`로 개설 → 글쓰기 화면으로 간다. 블로그 메인은 빈 상태다.
10. 주소창에 `/blog/new` 직접 입력 → 이미 블로그가 있어 막힌다 (US1-9).
11. 로그아웃 후 `/manage/write` 직접 입력 → 로그인 화면으로 간다 (US1-10).
12. (소셜 키가 있으면) 새 소셜 계정으로 로그인 → 동의·닉네임 한 화면, 닉네임 칸이 제공사 닉네임으로 채워져 있다 → 가입 후 원래 화면 (US1-1). 로그인 중 취소 → 이유 안내, 아무것도 안 바뀜 (US1-2).

### 이야기 2. 글 쓰고 발행·수정·삭제

1. 회원 A로 **새 글** → 빈 에디터 (US2-1).
2. 제목에 공백만 넣고 발행 → 제목 오류. 제목을 넣고 본문에 빈 줄만 두면 본문 오류. 본문에 이미지 한 장만 두면 발행된다 (US2-2, POST-01a).
3. 제목·본문(굵게, 기울임, 글자색, 정렬, 코드 블록, 외부 링크, 이미지 2장)·태그 `여행`을 넣고 카테고리 없이 발행 → `/minju-a/2` 같은 번호 주소의 상세 화면, 공감·댓글·조회 0, 카테고리 '미분류'. 외부 링크는 새 창으로 열린다 (US2-3, US2-4, POST-01b, POST-01d).
4. 개발자 도구에서 네트워크를 느리게 하고 발행을 세 번 연달아 누른다 → 글은 하나 (US2-5).
5. 글을 수정 → 주소 번호·발행일·조회수 그대로 (US2-6).
6. 본문에 `<img src=x onerror=alert(1)>`, `<script>alert(1)</script>`, `javascript:` 링크를 붙여 넣어 발행 → 어느 화면에서도 경고창이 뜨지 않는다. 같은 문자열을 제목·태그·블로그 이름·닉네임에도 넣어 본다 (US2-9, SC-010).
7. 비공개 글을 하나 발행하고 그 주소를 시크릿 창에서 연다 → 404 (US2-8).
8. 글 하나를 삭제 → 확인 창 → 같은 주소가 404. 새 글을 발행하면 지운 번호가 아니라 다음 번호를 받는다 (US2-7, POST-01d).
9. 비공개로 발행한 글을 공개로 바꾼다 → 발행일이 바꾼 시각이 되고 홈 맨 위에 나온다 (COM-P02).

### 이야기 3. 블로그 둘러보기

1. 회원 A로 글 12개를 발행한다(`uv run python manage.py seed_demo --posts 12 --blog minju-a`로 대신 가능).
2. 시크릿 창에서 `/minju-a` → 10개, `?page=2` → 나머지, `?page=9` → 빈 목록 (US3-1, US3-6).
3. 사이드바: '전체 글'이 맨 위, '미분류'가 맨 아래, 비공개 글은 목록과 개수에서 빠짐 (US3-2, US3-3).
4. 카테고리를 만들어 글을 넣고 카테고리 이름을 바꾼다 → 카테고리 주소(`/minju-a/category/3`)가 그대로 열린다 (CAT-02).
5. 태그 `Travel`을 단 글을 쓴다 → 기존 `travel` 태그와 같은 태그가 된다 (TAG-01).
6. 블로그 검색에 `  TRAVEL  `과 `travel` → 같은 결과. 없는 단어 → 안내 + 검색어 유지 (US3-4, US3-5).
7. `/no-such-blog` → 404 (US3-7).

### 이야기 4. 홈

1. 회원 B로 블로그를 하나 더 만들어 공개 글 1개, 비공개 글 1개를 쓴다.
2. 시크릿 창(비회원)에서 `/` → 랜딩 없이 최신 글 목록. 글마다 제목·블로그 이름·발행일·요약. B의 비공개 글은 없다 (US4-1, US4-2).
3. **더 불러오기**를 끝까지 → 같은 글 두 번 없음 (US4-3). 브라우저 JS를 끄고 다시 → "다음" 링크로 같은 결과.

### 이야기 5. 댓글과 공감

1. 비회원으로 A의 글에서 공감 → 로그인 화면 → 로그인 후 같은 글로 돌아온다 (US5-1).
2. 회원 B로 댓글 등록 → 목록 끝에 닉네임·날짜·시각, 댓글 수 +1. 등록을 연달아 눌러도 하나 (US5-2, US5-3).
3. 공감 → 다시 공감(취소) → 새로고침 → 수치가 실제와 같다 (US5-4).
4. 회원 A(주인)로 B의 댓글 삭제 가능, 수정 버튼은 없음 (US5-5).
5. 회원 A로 자기 글 공감 → 막힌다 (SOC-01).

### 이야기 6. 권한과 관리자 영역

1. 회원 B로 `/manage/write/{A의 글 번호}` → 404(B의 블로그에 그 번호가 없음). `/admin` → 403 (US6-2).
2. 비회원으로 `/me` → 로그인 후 `/me`로 돌아온다 (US6-1).
3. 관리자 계정으로 로그인 → `/admin` 열림. 가입 화면에는 관리자가 되는 방법이 없다 (US6-5).
4. 운영 설정(`DJANGO_SETTINGS_MODULE=config.settings.prod`)으로 띄우고 일부러 오류를 낸다 → "잠시 후 다시 시도" 화면, 내부 정보 없음 (US6-4).
5. 휴대폰 크기(개발자 도구 360px)로 위 흐름을 다시 → 가로 스크롤 없음, 사이드바는 본문 아래 접기 (SC-008).
