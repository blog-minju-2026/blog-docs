# Implementation Plan: 한채 블로그 플랫폼

**Branch**: `001-blog` | **Date**: 2026-10-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-blog/spec.md` (요구사항 ID는 통합본 기능 ID, 2026-10-08 판)
**Constitution**: [v1.0.0](../../.specify/memory/constitution.md)

## Summary

티스토리처럼 회원마다 블로그 하나를 열어 글을 쓰고, 홈·검색·구독으로 다른 블로그의 글을 발견하고, 댓글·공감으로 소통하는 서비스를 만든다.

민주가 정한 **HTML·CSS·JavaScript + Python** 위에서, 서버가 HTML을 그려 보내는 **Django 5.2 LTS** 웹 앱 하나로 만든다. 데이터는 팀 ERD 컨벤션대로 **MySQL 8.4**(대소문자 무시 정렬 규칙), 이메일·카카오·구글·네이버 로그인은 **django-allauth**, WYSIWYG 에디터는 **Quill 2** + 서버 정제 **nh3**, 정각 인기 글 집계는 **cron이 실행하는 관리 명령**이다. 배포는 리눅스 서버 한 대에 Docker Compose로 올린다. 각 선택의 이유와 대안은 [research.md](./research.md), 테이블과 ERD는 [data-model.md](./data-model.md)에 있다.

구현 순서는 spec 우선순위를 따른다(원칙 VI). **P1(이야기 1~6)만으로 "가입 → 개설 → 발행 → 홈에서 발견 → 읽기·댓글·공감" 한 바퀴가 돌게** 먼저 만들고, P2·P3를 이야기 단위로 더한다.

## Technical Context

**Language/Version**: Python 3.13 (서버), HTML5·CSS3·JavaScript ES2022 모듈 (화면, 빌드 없음)
**Primary Dependencies**: Django 5.2 LTS, django-allauth 65.x(이메일 + kakao·google·naver), mysqlclient, nh3, Pillow, argon2-cffi, Gunicorn. 화면: Quill 2(정적 파일로 포함)
**Storage**: MySQL 8.4 LTS (`utf8mb4`, `utf8mb4_0900_as_ci`). 이미지는 서버 디스크(`MEDIA_ROOT`). 세션·로그인 실패 횟수는 DB(세션 테이블, DB 캐시)
**Testing**: pytest + pytest-django, Playwright for Python(크로미움·웹킷, 360px), ruff. 테스트 DB도 MySQL 8.4
**Target Platform**: 리눅스 서버 1대(Docker Compose: Caddy + Gunicorn/Django + MySQL). 사용자는 최신 크롬·사파리·엣지(SC-009)
**Project Type**: 웹 애플리케이션 (서버 렌더링 단일 Django 프로젝트)
**Performance Goals**: 글 목록·상세 2초 안에 내용 표시(SC-007), 정각 후 5분 안 순위 갱신(SC-006). 서버 응답 p95 300ms 이하, 화면 하나의 쿼리 수가 글 개수와 무관(N+1 금지)
**Constraints**: 볼 수 없는 글 노출 0건(SC-003), 권한표 ✕ 칸 100% 거부(SC-004), 중복 생성 0건(SC-005), 스크립트 실행 0건(SC-010), 360px 가로 스크롤 없음(SC-008), 한국 시간 표시(COM-P07), JS가 꺼져도 읽기·목록 동작(원칙 VI)
**Scale/Scope**: 첫해 가정 회원 1천 명, 블로그 수백 개, 글 1만 개, 동시 접속 100명 이하. 화면 약 35개, 요구사항 110여 개(P1 약 55개)

### 의존성과 들이는 이유 (원칙 VI)

| 의존성 | 하는 일 | 표준 라이브러리·기존 도구로 안 되는 이유 | 버린 대안 |
| --- | --- | --- | --- |
| Django 5.2 LTS | 웹 프레임워크, ORM, 마이그레이션, 템플릿, CSRF, 세션 | 기술 제약의 Python 서버를 만들 기반 | Flask, FastAPI (research 1절) |
| django-allauth | 이메일 가입·인증·재설정, 소셜 로그인 3곳 | OAuth 3곳과 메일 인증을 직접 짜면 보안 실수 위험이 크다(원칙 III) | 직접 구현, Authlib (research 4절) |
| mysqlclient | Django ↔ MySQL 드라이버 | DB 연결에 필요 | PyMySQL(느림) |
| nh3 | 본문 HTML 허용 목록 정제 | 원칙 III의 허용 목록 정제를 직접 짜면 우회되기 쉽다 | bleach(개발 중단) |
| Pillow | 이미지 형식 확인, 방향 보정, 작은 이미지 | 원칙 III "내용으로 이미지인지 확인" | 확장자·MIME 검사(위장 못 막음) |
| argon2-cffi | Argon2 비밀번호 해시 | Django 기본 PBKDF2보다 강하고 원칙 III가 예로 든 해시 | bcrypt(비슷함, Argon2가 Django 권장) |
| Gunicorn | 운영 WSGI 서버 | `runserver`는 운영용이 아니다 | uWSGI(설정이 복잡) |
| Quill 2 | WYSIWYG 에디터 | POST-01b 서식 편집을 직접 만들 수 없다 | TinyMCE·CKEditor(라이선스), Tiptap(빌드) (research 5절) |
| pytest, pytest-django | 테스트 실행 | Django `unittest`보다 매개변수 테스트(권한표)가 쉽다 | Django 기본 테스트 러너 |
| Playwright | 브라우저 E2E, 360px | SC-008·SC-009는 실제 브라우저로만 확인된다 | Selenium (research 13절) |
| ruff | 코드 검사·서식 | 하나로 flake8·isort·black 역할 | 각각 따로 |

운영 구성 요소: Caddy(HTTPS·정적 파일), MySQL 8.4, Mailpit(개발용 가짜 메일함). 이 밖의 라이브러리는 이 표를 고친 뒤 들인다.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 확인할 것 | Phase 0 전 | Phase 1 후 |
| --- | --- | --- | --- |
| **I. 명세가 먼저다** | 설계한 모든 화면·API·테이블이 spec 요구사항 ID로 거슬러 올라가는가. spec에 없는 기능을 넣지 않았는가 | ✅ spec 요구사항만 다룬다. 통합본 '자율' 값과 review.md의 plan 항목만 plan에서 정했다 | ✅ [pages.md](./contracts/pages.md)·[api.md](./contracts/api.md)의 모든 줄과 [data-model.md](./data-model.md)의 모든 규칙에 요구사항 ID가 있다. 블로그 주인 조회수 제외처럼 spec에 없는 규칙은 넣지 않았다(research 8절) |
| **II. 권한은 서버가 지킨다** | 모든 요청을 서버가 권한표로 검사하는가. 볼 수 없는 글은 404인가. 공개 범위 판단이 한곳인가. 관리자가 남의 내용을 고칠 수 없는가 | ✅ 데코레이터 3개 + `visibility.py` 한 모듈(research 10절) | ✅ pages.md 모든 주소에 권한, data-model 4절 '볼 수 있는 글'. 순위도 보여 줄 때 다시 거른다. 관리자 화면에 내용 수정 기능 없음 |
| **III. 기본이 안전하다** | 이스케이프·허용 목록 정제, CSRF, GET 무변경, Argon2, 비밀 값 비노출, 내용으로 이미지 확인, 오류 화면 내부 정보 없음, 비밀 값 환경 변수 | ✅ Django 기본 + nh3 + Pillow + Argon2 + CSP 미들웨어(research 5·6·17절) | ✅ api.md 공통 규칙(CSRF 헤더, 오류 형식), pages.md 공통 규칙(상태 변경은 POST), `.env.example`만 커밋 |
| **IV. 데이터는 언제나 맞는다** | 연타 한 번만(DB 제약), 여러 단계 작업 한 트랜잭션, 수치가 실제와 같음, 주소 불변·영구 예약, 영속 저장, 마이그레이션만 | ✅ client_token·유일 키, 수치는 매번 센다(research 9절) | ✅ data-model 7·8·9절. 글 번호는 블로그 행 잠금 + 유일 키 |
| **V. 테스트로 확인한다** | 수용 시나리오마다 테스트, 기능과 테스트 같은 PR, 권한·공개 범위·중복은 테스트 먼저, 네 상태 권한표 테스트, 명령 하나 | ✅ pytest `req` 표시, 권한표 데이터 테스트(research 13절) | ✅ 아래 '테스트 구성'. tasks.md에서 테스트 작업을 구현 앞에 둔다 |
| **VI. 단순하게 만든다** | 서버 렌더링, JS는 필요한 곳만, JS 없이 읽기 동작, 새 도구에 이유, P1 먼저, 미리 만들지 않음 | ✅ 웹 앱 1개 + DB 1개. 작업 큐·검색 엔진·SPA 없음 | ✅ 의존성 표에 이유. P3 테이블은 그때 만든다. 좁은 화면 사이드바도 JS 없이 `<details>` |

**결과**: 위반 없음. Complexity Tracking은 비워 둔다.

## Project Structure

### Documentation (this feature)

```text
specs/001-blog/
├── spec.md              # 기능 명세 (/speckit.specify, /speckit.clarify)
├── review.md            # 통합본 대조 검토
├── plan.md              # 이 문서 (/speckit.plan)
├── research.md          # Phase 0: 기술 결정, 자율 값, 주제 slug
├── data-model.md        # Phase 1: ERD, 테이블, 상태, 삭제 규칙, DB 제약
├── quickstart.md        # Phase 1: 로컬 실행과 P1 확인 순서
├── contracts/
│   ├── pages.md         # Phase 1: HTML 화면 주소와 권한
│   └── api.md           # Phase 1: 화면 JS가 부르는 JSON API
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2: /speckit.tasks가 만든다 (아직 없음)
```

### Source Code (repository root)

코드는 이 저장소 루트에 둔다. Spec Kit은 명세(`specs/`)와 코드를 한 저장소에서 다루는 것을 전제로 하므로, 저장소 이름이 `blog-docs`여도 그대로 쓴다(이름은 나중에 바꿔도 된다).

```text
manage.py
pyproject.toml                # 의존성, ruff·pytest 설정 (uv)
.env.example                  # 비밀 값 이름만. .env는 커밋하지 않음
docker-compose.yml            # db(MySQL 8.4), mailpit, web, caddy
config/
├── settings/
│   ├── base.py               # TIME_ZONE=Asia/Seoul, allauth, 업로드 상한, research 14절 값
│   ├── dev.py
│   └── prod.py               # DEBUG=False, 보안 쿠키, HSTS, SMTP
├── urls.py                   # 서비스 경로 먼저, 맨 끝에 /{blog}/ 경로
└── wsgi.py
apps/
├── core/                     # 권한 데코레이터, 오류 화면, 페이지·커서, client_token, CSP 미들웨어, 시간 표시
├── accounts/                 # User, 가입 폼(동의·닉네임), allauth 어댑터(AUTH-01d), 이용 제한 미들웨어, create_service_admin
├── blogs/                    # Blog, reserved.py, 개설·설정, 사이드바, 블로그 메인, 방명록
├── posts/                    # Post·Category·Tag·Topic·Image·PostView, visibility.py, sanitize.py(nh3), 글쓰기·상세·목록·블로그 검색, 이미지 업로드
├── comments/                 # Comment, 댓글 화면·API
├── social/                   # PostLike, Subscription, 피드 (P3: 저장·알림)
├── discovery/                # 홈, 주제별 글, 통합 검색, 순위 스냅숏, compute_rankings
└── moderation/               # UserSanction, AdminLog, 숨김, 서비스 관리 화면 (P3: 신고·공지)
templates/
├── base.html                 # 헤더(로고·통합 검색·로그인), 푸터(이용약관·개인정보처리방침)
├── blog_base.html            # 블로그 화면 공통 + 사이드바
├── errors/{403,404,500}.html
└── {앱 이름}/...
static/
├── css/                      # tokens.css(색·글꼴 변수), base.css, blog.css, editor.css
├── js/                       # api.js(fetch + CSRF + 401 처리), editor.js, toggle.js(공감·구독), comments.js, load-more.js, form-guard.js(입력 백업)
└── vendor/quill/
tests/
├── conftest.py               # MySQL 테스트 DB, 사용자 상태 픽스처 4종, --req 옵션
├── permissions/              # matrix.py(COM-01 표 데이터) + test_matrix.py
├── unit/                     # 정제, 검증, 공개 범위, 발행일·글 번호 규칙
├── integration/              # 화면·API (Django test client), 쿼리 수
└── e2e/                      # Playwright: P1 한 바퀴, 360px, 크로미움·웹킷
deploy/
├── Caddyfile
├── crontab                   # 0 * * * * compute_rankings / 30 4 * * * cleanup / (P3) * * * * * publish_scheduled_posts
└── backup.sh
```

**Structure Decision**: Django 프로젝트 하나에 도메인별 앱 8개를 둔다. 화면은 별도 프로젝트 없이 `templates/`와 `static/`에 있다. `/{blog}` 경로는 다른 모든 서비스 경로 뒤에 오도록 `config/urls.py` 맨 끝에 붙이고, 서비스 경로의 첫 단어는 모두 블로그 주소 예약어에 넣는다([pages.md](./contracts/pages.md) 끝). 이 일치는 테스트(`tests/unit/test_reserved_words.py`가 URL 설정의 첫 단어가 모두 예약어에 있는지 확인)로 지킨다.

## 핵심 설계

### 화면과 주소

전체 목록과 권한은 [contracts/pages.md](./contracts/pages.md).

- 서비스: `/`, `/search`, `/topic/{slug}`, `/feed`, `/terms`, `/privacy` (P3: `/ranking`)
- 회원: `/accounts/...`(allauth), `/me`, `/blog/new`
- 블로그 관리: `/manage/write`, `/manage/posts`, `/manage/comments`, `/manage/categories`, `/manage/settings`. 주소에 블로그가 없고 언제나 "내 블로그"라 남의 관리 화면이라는 주소가 생기지 않는다
- 블로그: `/{blog}`, `/{blog}/{no}`, `/{blog}/category/{id}`, `/{blog}/uncategorized`, `/{blog}/tag/{name}`, `/{blog}/tags`, `/{blog}/search`, `/{blog}/guestbook`
- 서비스 관리: `/admin/...` (Django 기본 관리 도구는 운영자 전용 `/django-admin/`)

### 요청 한 번의 흐름 (글 상세 예)

1. `config/urls.py`가 `/{blog}/{no}`를 `posts.views.post_detail`로 보낸다.
2. 미들웨어가 로그인 회원의 이용 제한을 확인한다. 제한 중이면 로그아웃시키고 사유·기한을 안내한다(ADMIN-02).
3. 뷰가 `get_post_for_viewer_or_404(blog, no, viewer)`를 부른다. POST-04a 순서로 판단하고 볼 수 없으면 404(원칙 II).
4. 조회 기록을 남긴다(30분 중복 제외, research 8절, P2).
5. 템플릿이 정제된 본문(`safe`는 이 값 하나만)과 나머지 자동 이스케이프 값을 그린다(원칙 III).
6. 공감 버튼·댓글은 `static/js/`가 [api.md](./contracts/api.md) API로 처리한다. JS가 없으면 댓글은 폼 전송으로 되고 공감 버튼은 로그인·폼 전송으로 동작한다.

### 글 발행 한 번의 흐름 (POST-01, COM-P06)

1. 새 글 화면이 일회용 `client_token`을 숨은 칸에 넣는다. 에디터 입력은 2초마다 브라우저에 백업한다.
2. 발행 요청이 오면 폼 검증(제목 → 본문 순서, POST-01a) → nh3 정제 → 요약·첫 이미지·빈 본문 판단.
3. 한 트랜잭션: 블로그 행 잠금 → `last_post_no + 1` → 글 저장(`(blog_id, client_token)` 유일) → 태그 정리·연결 → 이미지 연결.
4. 같은 토큰이 이미 있으면 그 글로 보낸다. 성공하면 `302 → /{blog}/{no}`, 브라우저 백업을 지운다.
5. 실패하면 같은 화면에 첫 번째 오류와 입력한 내용을 그대로 보여 준다(COM-02a).

### 보안 기본값 (원칙 III)

- 운영: `DEBUG=False`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, `SECURE_HSTS_SECONDS`, `X_FRAME_OPTIONS=DENY`, `SECURE_CONTENT_TYPE_NOSNIFF`
- CSP: research 17절의 헤더. 인라인 `<script>` 금지
- 로그인 실패 제한(research 14절), 비밀번호 Argon2, 재설정 요청은 가입 여부와 관계없이 같은 안내
- 로그·오류 화면에 비밀번호·토큰·세션 값을 남기지 않는다(AUTH-01b, COM-P05)
- `next` 파라미터는 같은 사이트 주소만 허용(열린 리디렉션 방지)

### 테스트 구성 (원칙 V)

| 종류 | 무엇을 | 먼저 쓰는가 |
| --- | --- | --- |
| 권한표 | COM-01의 모든 ✕ 칸 × 네 상태, 주소 직접 요청(SC-004) | **먼저** |
| 공개 범위 | POST-06a의 볼 수 없는 글 6종 × 목록·검색·홈·순위·피드·사이드바·글 수·이전/다음·직접 주소(SC-003) | **먼저** |
| 중복 처리 | 발행·댓글·공감·구독 연속 요청, 동시 발행 글 번호(SC-005) | **먼저** |
| 수용 시나리오 | spec 이야기 1~12의 Given/When/Then 하나당 하나 이상(`req` 표시에 `US2-8` 등) | 기능과 같은 PR |
| 정제 | 스크립트·이벤트 속성·`javascript:` 링크가 든 제목·본문·댓글·이름·닉네임(SC-010) | 기능과 같은 PR |
| 쿼리 수 | 목록 화면마다 글 10개와 20개일 때 쿼리 수가 같음 | 기능과 같은 PR |
| E2E | P1 한 바퀴(SC-002), 360px 가로 스크롤 없음(SC-008), 크로미움·웹킷(SC-009) | P1 끝 |

### 단계별 범위

| 단계 | 사용자 이야기 | 만들어지는 것 |
| --- | --- | --- |
| 기반 | — | 프로젝트 골격, 설정, Docker Compose, User 모델, P1·P2 테이블 마이그레이션, 주제 10개, 공통 레이아웃·오류 화면, 테스트 환경, 권한표·공개 범위 테스트 틀 |
| P1 | 1~6 | 가입·로그인·동의·개설, 글쓰기(Quill·이미지)·수정·삭제, 블로그 메인·카테고리·태그·블로그 검색·사이드바, 홈 최신 글, 댓글·공감, 권한·오류 화면·관리자 계정 |
| P2 | 7~11 | 조회수·정각 인기 글, 주제·통합 검색, 임시저장·대표 이미지·하위 카테고리·순서·이전/다음 글·태그 모아 보기·주소 복사, 구독·피드, 글·댓글 관리, 방명록, 로그인 유지, 프로필 수정, 이용 제한·숨김 |
| P3 | 12 | 인기 블로거·랭킹 전체보기, 예약 발행, 답글·비밀댓글·댓글 허용, 저장, 알림, 맞구독, 추천 블로그, 블로그 꾸미기·삭제, 카테고리 비공개, 태그 관리, 방문 통계, 차단·금칙어, 신고, 블로그 이용 제한, 공지·이력·대시보드, 탈퇴 |

### 확정한 값

통합본이 '자율'로 둔 값(이미지 10MB, 로그인 유지 14일, 조회 중복 30분, 로그인 실패 5분 5회 등)과 주제 slug는 [research.md](./research.md) 14·15절에 있다. 홈 영역별 노출 개수는 잠정값이며 홈 디자인 후 다시 정한다.

## 남은 확인 사항

plan을 막지는 않지만 구현 전에 확인할 것들이다.

- **SC-006(5분)·SC-007(2초, 90%)**: spec이 가정한 값이다. 이 plan은 그 값을 목표로 잡았다.
- **카카오 비즈 앱·네이버 검수**: 소셜 로그인을 실제로 열기 전에 신청한다(research 4절).
- **이용약관·개인정보처리방침 문안**: `/terms`, `/privacy` 화면은 만들지만 문안은 따로 준비해야 한다.
- **팀 공유**: 테이블 이름·열이 팀 ERD와 다른 점(data-model 10절)을 지원·서현과 비교할 때 참고한다.

## Complexity Tracking

원칙 위반이 없어 비워 둔다.

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| — | — | — |

## 다음 단계

`/speckit.tasks`로 이 plan을 바탕으로 작업 목록(`tasks.md`)을 만든다. 작업은 기반 → P1 이야기 1~6 → P2 → P3 순서로, 이야기마다 혼자 구현·시연할 수 있게 나누고, 원칙 V에 따라 테스트 작업을 구현 작업 앞에 둔다.
