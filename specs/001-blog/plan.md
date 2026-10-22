# Implementation Plan: 한채 블로그 플랫폼

**Branch**: `001-blog` | **Date**: 2026-10-08 | **Amended**: 2026-10-22 (실제 구현에 맞춰 화면 방식 · 구성 · 배포를 고침) | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-blog/spec.md` (요구사항 ID는 통합본 기능 ID, 2026-10-08 판)
**Constitution**: [v2.0.0](../../.specify/memory/constitution.md)

## Summary

티스토리처럼 회원마다 블로그(한채) 하나를 열어 글을 쓰고, 홈·검색·구독(이웃)으로 다른 블로그의 글을 발견하고, 댓글·공감으로 소통하는 서비스를 만든다.

민주가 정한 **HTML·CSS·JavaScript + Python** 위에서, 화면은 **정적 HTML 파일 + 빌드 없는 JavaScript**, 서버는 **Django 5.2 LTS + Django REST framework의 JSON API**로 만든다. 화면 파일과 API는 같은 Django 서버가 같은 주소에서 내보내 세션 쿠키와 CSRF가 그대로 통한다. 데이터는 **MySQL 8.0**(학교 서버에서 발급), 이메일·카카오·구글·네이버 로그인은 **django-allauth**, 글쓰기 에디터는 **직접 만든 contenteditable 에디터** + 서버 정제 **nh3**다. 배포는 GitHub Actions가 Docker 이미지를 만들어 학교 서버(조선대학교)에 올리고, 서버의 공용 nginx 뒤에서 컨테이너 두 개가 번갈아 받는다.

구현 순서는 spec 우선순위를 따른다(원칙 VI). **P1(이야기 1~6)만으로 "가입 → 개설 → 발행 → 홈에서 발견 → 읽기·댓글·공감" 한 바퀴가 돌게** 먼저 만들고, P2·P3를 이야기 단위로 더했다.

### 처음 판(2026-10-08)에서 바뀐 결정

| 항목 | 처음 판 | 지금 (실제 구현) | 바꾼 이유 |
| --- | --- | --- | --- |
| 화면 방식 | Django 템플릿이 HTML을 그림, JS는 공감·구독 등 일부만. JS 없이 읽기 동작 | 정적 HTML + `js/pages/*.js`가 JSON API를 불러 그림. JS 필수 | 시안(디자인 시스템 「한채」)을 HTML·CSS로 그대로 옮기고, 권한·공개 범위를 API 테스트로 한곳에서 확인하려고. 원칙 VI 개정(v2.0.0) |
| 서버 응답 | HTML 화면 + 일부 JSON | 화면 파일은 그대로 내보내고, 데이터는 모두 `/api/...` JSON ([API 명세서](../../docs/API명세서.md)) | 위와 같음 |
| 저장소 | `blog-docs` 하나에 명세와 코드 | 명세는 `blog-docs`, 코드는 `blog-code` | 코드 저장소만 배포 대상으로 두려고 |
| 화면 주소 | `/{blog}/{no}`, `/manage/...` | `/yard?address=…`, `/post?address=…&no=…`, `/write`, `/manage-posts` 등 (아래 '화면과 주소') | 화면 파일 하나 = 주소 하나. 서버 경로 규칙과 블로그 주소 예약어가 얽히지 않는다. 서브도메인 주소(`{주소}.도메인`)는 도메인이 생기면 연다 |
| 에디터 | Quill 2 | 직접 만든 contenteditable 에디터(`js/editor.js`) | 쓰는 서식이 적고, 빌드 없이 넣을 수 있다. 정제는 어차피 서버(nh3)가 한다 |
| DB | MySQL 8.4 LTS | MySQL 8.0 (학교 서버 발급, 노트북은 8.0.41) | 학교 서버가 주는 판을 쓴다 |
| 테스트 | pytest + pytest-django, Playwright E2E | Django 기본 테스트 러너(`APITestCase`), 브라우저 확인은 PR 체크리스트 | 의존성을 줄였다. E2E는 아래 '남은 확인 사항' |
| 운영 구성 | Caddy + Docker Compose + cron | 학교 서버 공용 nginx → 컨테이너 2개(무중단 교체), 정기 작업은 GitHub Actions 예약 실행 | 학교 서버는 nginx를 함께 쓰고 cron을 둘 수 없다 |
| 정각 순위 | cron이 매 정각 계산 | 그 시간의 첫 요청이 직전 정각 기준으로 계산해 저장 | 정각마다 도는 작업을 둘 수 없다 (결과는 같다) |
| 조회수 기록 | 글 상세 `GET`이 기록 | 화면이 `POST /api/blogs/{address}/posts/{no}/views`로 따로 남김 (30분 중복 제외) | 화면이 API를 부르므로 GET이 상태를 바꾸지 않게 됐다 (원칙 III) |
| 로그인 유지 | 14일 | 브라우저를 닫으면 로그아웃, 열어 둔 채여도 마지막 사용에서 2주 | 같은 기기를 함께 쓸 때 로그인이 남지 않게 (2026-10-22) |

## Technical Context

**Language/Version**: Python 3.12 (서버, Docker `python:3.12-slim`), HTML5·CSS3·JavaScript ES2022 (화면, 빌드 없음, 일반 `<script src>`)
**Primary Dependencies**: Django 5.2 LTS, Django REST framework, django-allauth 65.x(이메일 + kakao·google·naver), mysqlclient, nh3, Pillow, argon2-cffi, Gunicorn, WhiteNoise, django-cors-headers, python-dotenv. 화면: 외부 라이브러리 없음
**Storage**: MySQL 8.0 (`utf8mb4`). 이미지는 서버 디스크(`MEDIA_ROOT`, 두 컨테이너가 함께 쓰는 `~/hanchae/media`). 세션은 DB
**Testing**: Django 기본 테스트 러너, `rest_framework.test.APITestCase`. 테스트 DB도 MySQL. 앱마다 `test_*.py`
**Target Platform**: 학교 서버(조선대학교) 1대: 공용 nginx → Gunicorn/Django 컨테이너 2개. 사용자는 최신 크롬·사파리·엣지(SC-009)
**Project Type**: 웹 애플리케이션 (정적 화면 + JSON API, Django 서버 하나가 둘 다 내보냄)
**Performance Goals**: 글 목록·상세 2초 안에 내용 표시(SC-007), 정각 후 5분 안 순위 갱신(SC-006). 한 API의 쿼리 수가 글 개수와 무관(N+1 금지)
**Constraints**: 볼 수 없는 글 노출 0건(SC-003), 권한표 ✕ 칸 100% 거부(SC-004), 중복 생성 0건(SC-005), 스크립트 실행 0건(SC-010), 360px 가로 스크롤 없음(SC-008), 한국 시간 표시(COM-P07). JavaScript 필수(원칙 VI)
**Scale/Scope**: 첫해 가정 회원 1천 명, 블로그 수백 개, 글 1만 개, 동시 접속 100명 이하. 화면 HTML 23개

### 의존성과 들이는 이유 (원칙 VI)

| 의존성 | 하는 일 | 표준 라이브러리·기존 도구로 안 되는 이유 | 버린 대안 |
| --- | --- | --- | --- |
| Django 5.2 LTS | 웹 프레임워크, ORM, 마이그레이션, CSRF, 세션 | 기술 제약의 Python 서버를 만들 기반 | Flask, FastAPI (research 1절) |
| Django REST framework | JSON API: 입력 검증(serializer), 권한 클래스, 요청 횟수 제한(throttle) | 화면이 API를 부르는 방식(원칙 VI)에서 검증 · 오류 모양 · 횟수 제한을 API마다 직접 짜면 빠뜨리기 쉽다 | Django 뷰에서 `JsonResponse` 직접 |
| django-allauth | 이메일 인증 · 비밀번호 재설정, 소셜 로그인 3곳 | OAuth 3곳과 메일 인증을 직접 짜면 보안 실수 위험이 크다(원칙 III) | 직접 구현, Authlib (research 4절) |
| mysqlclient | Django ↔ MySQL 드라이버 | DB 연결에 필요 | PyMySQL(느림) |
| nh3 | 본문 HTML 허용 목록 정제 | 원칙 III의 허용 목록 정제를 직접 짜면 우회되기 쉽다 | bleach(개발 중단) |
| Pillow | 이미지 형식 확인, 방향 보정, 작은 이미지 | 원칙 III "내용으로 이미지인지 확인" | 확장자·MIME 검사(위장 못 막음) |
| argon2-cffi | Argon2 비밀번호 해시 | Django 기본 PBKDF2보다 강하고 원칙 III가 예로 든 해시 | bcrypt |
| Gunicorn | 운영 WSGI 서버 | `runserver`는 운영용이 아니다 | uWSGI(설정이 복잡) |
| WhiteNoise | 관리 도구(`/django-admin/`)의 정적 파일을 컨테이너가 직접 내보냄 | 학교 서버 nginx는 프록시만 하고 컨테이너 안 파일을 읽지 못한다 | nginx에 정적 폴더 연결 |
| django-cors-headers | 한채 서브도메인(`{주소}.도메인`)에서 API를 부를 때 쿠키를 함께 보내게 허용 | 서브도메인 주소(API 명세서 4.3)를 열면 출처가 달라진다. 지금은 같은 주소라 쓰이지 않는다 | 서브도메인을 열 때 들이기 |
| python-dotenv | `backend/.env`에서 설정 읽기 | 노트북 개발에서 환경 변수를 파일로 넣으려고 | 셸에서 직접 export |

화면은 외부 라이브러리를 쓰지 않는다. 에디터(`js/editor.js`), 요청(`js/api.js`), 공통 조각(`js/common.js`)은 직접 만들었다.

운영 구성 요소와 들이는 이유:

- Docker: 개발(`docker compose up`)과 운영을 같은 이미지로 띄운다. 이미지 하나가 API와 화면 파일을 함께 담는다.
- GitHub Actions: `main`에 합치면 이미지를 만들어 SSH로 서버에 올리고(`deploy.yml`), 하루 한 번 정리 작업을 부른다(`maintenance.yml`). 학교 서버에 cron을 둘 수 없어 예약 실행을 GitHub이 대신한다.
- 학교 서버 공용 nginx: 도메인을 내 두 포트로 나눠 보낸다. 컨테이너를 하나씩 바꿔 배포 중에도 끊기지 않는다.

이 밖의 라이브러리는 이 표를 고친 뒤 들인다.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.* 2026-10-22 개정 때 v2.0.0 기준으로 다시 확인했다.

| 원칙 | 확인할 것 | 지금 구현 |
| --- | --- | --- |
| **I. 명세가 먼저다** | 모든 화면·API·테이블이 spec 요구사항 ID로 거슬러 올라가는가. spec에 없는 기능을 넣지 않았는가 | ✅ API는 [API 명세서](../../docs/API명세서.md), 코드 주석 · 커밋에 기능 ID(예: `POST-11`, `BLOG-04`). 화면 방식이 바뀐 것은 이 개정으로 문서에 반영했다 |
| **II. 권한은 서버가 지킨다** | 모든 API가 권한표로 검사하는가. 볼 수 없는 글은 404인가. 공개 범위 판단이 한곳인가. 관리자가 남의 내용을 고칠 수 없는가 | ✅ 공개 범위는 `apps/common/access.py`(`visible_posts` · `visible_blogs` · `get_visible_blog_or_404`) 한곳, 주인 확인은 `owned_blog`. 화면의 숨김 · 이동은 편의 |
| **III. 기본이 안전하다** | 이스케이프·허용 목록 정제, CSRF, GET 무변경, Argon2, 비밀 값 비노출, 내용으로 이미지 확인, 오류 내부 정보 없음, 공개 로그에 개인 정보 없음 | ✅ 화면은 `escapeHTML` · `textContent`, 본문만 nh3 정제 후 HTML. 상태 변경 API는 `X-CSRFToken` 확인(`EnforceCsrfMixin`). 오류는 `{error:{code,message}}`만. 정기 작업 로그는 개수만. ⚠ 순위 계산 GET (Complexity Tracking) · CSP 미적용 (남은 확인 사항) |
| **IV. 데이터는 언제나 맞는다** | 연타 한 번만(DB 제약), 여러 단계 작업 한 트랜잭션, 수치가 실제와 같음, 주소 불변·영구 예약, 영속 저장, 마이그레이션만 | ✅ `client_token` 유일 키, 글 번호는 블로그 행 잠금 + 유일 키, 수치는 매번 센다. 탈퇴 · 한채 허물기는 한 트랜잭션이고 파일은 커밋 뒤 지운다. 허문 한채의 주소는 행을 남겨 예약 |
| **V. 테스트로 확인한다** | 수용 시나리오마다 테스트, 기능과 테스트 같은 PR, 권한·공개 범위·중복은 테스트 먼저, 명령 하나 | ✅ `manage.py test apps` 하나(2026-10-22 기준 218개). 기능 PR마다 테스트를 함께 넣었다. ⚠ 브라우저 E2E 없음 (남은 확인 사항) |
| **VI. 단순하게 만든다** | 정적 HTML + 빌드 없는 JS + JSON API, 화면 하나 = 파일 하나, API 주소는 `store.js` 한곳, 프레임워크 · 번들러 없음, 실패하면 안내, 새 도구에 이유, P1 먼저 | ✅ 화면 HTML 23개 + `js/pages/` 21개, 화면 라이브러리 0개. `runPage`가 실패를 오류 안내로 바꾼다. 의존성 표에 이유 |

**결과**: 통과. 원칙과 다르게 처리한 곳은 아래 Complexity Tracking에 이유와 함께 적었다.

## Project Structure

### Documentation (blog-docs 저장소)

```text
docs/
├── 기능명세서.md          # 한채 기능명세서
├── API명세서.md           # 화면이 부르는 JSON API (화면 ↔ 서버의 기준)
└── 1팀_블로그_통합_기능명세서.md
specs/001-blog/
├── spec.md              # 기능 명세 (/speckit.specify, /speckit.clarify)
├── review.md            # 통합본 대조 검토
├── plan.md              # 이 문서 (/speckit.plan)
├── research.md          # Phase 0: 기술 결정, 자율 값, 주제 slug (처음 판 기준)
├── data-model.md        # Phase 1: ERD, 테이블, 상태, 삭제 규칙, DB 제약
├── quickstart.md
├── contracts/
│   ├── pages.md         # 처음 판의 서버 렌더링 화면 주소 (지금 주소는 아래 '화면과 주소')
│   └── api.md           # 처음 판의 API 계약 (지금 기준은 docs/API명세서.md)
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (blog-code 저장소)

```text
*.html                        # 화면 하나에 파일 하나 (index · yard · post · write · manage-posts · …, 404 · 500)
css/
├── hanchae.css               # 디자인 시스템 「한채」: 색·글꼴 변수, 공통 요소, 확인 창
└── pages/{화면}.css
js/
├── api.js                    # fetch + CSRF 헤더 + 오류(ApiError) 처리
├── auth.js                   # 로그인 · 가입 · 소셜 로그인 시작 · 현재 회원
├── store.js                  # API 주소를 모아 둔 한곳. 화면은 이것만 부른다
├── common.js                 # Links(화면 주소), 헤더 · 탭 · 확인 창 · 더 불러오기, escapeHTML, runPage
├── content.js                # 화면 문구 · 표시 규칙
├── editor.js                 # contenteditable 에디터
└── pages/{화면}.js           # 화면마다 하나: API를 불러 화면을 그리고 입력을 보낸다
assets/                       # 글꼴, 그림, releases.json(릴리즈 노트)
backend/
├── config/
│   ├── settings.py           # TIME_ZONE=Asia/Seoul, allauth, 보안 쿠키 · HSTS, 요청 횟수 제한
│   ├── urls.py               # /api/… → 앱들, /accounts/{제공사}/login(/callback) → allauth, 나머지 → 화면 파일
│   └── frontend.py           # 루트 *.html 과 css·js·assets만 내보냄. 404 · 500은 화면은 HTML, API는 JSON
└── apps/
    ├── common/               # 공개 범위(access.py), 오류, 권한, CSRF, 저장소 파일 지우기
    ├── accounts/             # 회원, 가입 · 인증 · 로그인, allauth 어댑터, 소셜 계정 잇기, 탈퇴
    ├── blogs/                # 한채(블로그), 개설 · 설정, 주소 예약, 한채 허물기
    ├── posts/                # 기록 · 방(카테고리) · 태그 · 골목(주제) · 사진 · 조회, 발행 · 임시저장, 본문 정제, 정기 정리
    ├── community/            # 댓글 · 공감 · 이웃(구독) · 방명록, 이웃 소식, 주인의 댓글 · 방명록 관리
    ├── rankings/             # 정각 순위
    └── moderation/           # 이용 제한, 숨김, 서비스 관리
Dockerfile · docker-compose.yml
deploy/                       # deploy.sh(컨테이너 2개 차례로 교체), nginx 설정 예, 소셜 로그인 안내
.github/workflows/            # deploy.yml, maintenance.yml
```

**Structure Decision**: 화면과 API를 한 저장소 · 한 Docker 이미지에 둔다. Django가 `/api/`는 API로, 나머지 주소는 화면 파일로 보낸다(`config/frontend.py`). 화면 파일은 정해진 폴더만 내보내 `backend/.env` 같은 파일이 새지 않는다. 한채 주소는 경로가 아니라 쿼리(`?address=`)로 받으므로 화면 이름과 겹쳐도 주소가 부딪히지 않는다. 블로그 주소 예약어(`RESERVED_ADDRESSES`: `www`, `api`, `admin`, `accounts`, `media` 등)는 서브도메인 주소(`{주소}.도메인`)를 열 때 서비스 이름과 겹치지 않게 하려고 둔다.

## 핵심 설계

### 화면과 주소

화면 하나는 HTML 파일 하나다. 주소의 쿼리로 어느 한채 · 어느 기록인지 받는다. 화면 주소는 `js/common.js`의 `Links` 한곳에서 만든다.

- 서비스: `/`(마을), `/search?q=…`, `/topic?slug=…`(골목), `/neighbors`(내 이웃 · 이웃 소식), `/releases`, `/terms`, `/privacy`
- 회원: `/login`(가입 · 로그인 · 소셜 가입 마무리), `/verify-email`, `/reset-password`, `/me`(내 정보 · 로그인 방법 · 탈퇴), `/build`(한채 짓기)
- 한채: `/yard?address=…`(마당 · 방 · 태그 · 검색), `/post?address=…&no=…`, `/guestbook?address=…`
- 한채 관리(언제나 내 한채): `/write`(`?no=` 수정, `?draft=` 이어 쓰기), `/manage-posts`(`?status=draft` 임시저장), `/manage-comments`, `/rooms`, `/settings`(한채 허물기 포함)
- 서비스 관리: `/admin` (Django 기본 관리 도구는 운영자 전용 `/django-admin/`)
- 소셜 로그인: `/accounts/{kakao|google|naver}/login/`과 `callback/`만 연다. 키를 넣은 제공사만 열린다

서브도메인 주소(`{주소}.도메인/{no}`, API 명세서 4.3)는 와일드카드 도메인이 생기면 연다(`HANCHAE_DOMAIN`).

### 화면 하나가 뜨는 흐름 (기록 읽기 예)

1. 브라우저가 `/post?address=minju&no=3`을 연다. Django가 `post.html`을 그대로 보낸다.
2. `post.html`이 공통 JS와 `js/pages/post.js`를 읽는다. `runPage(main)`이 화면을 시작하고, 실패하면 그 종류(없음 · 권한 · 연결 끊김 등)대로 안내 화면으로 바꾼다(원칙 VI).
3. `post.js`가 `Store.getPost('minju', 3)` → `GET /api/blogs/minju/posts/3`.
4. API가 공개 범위를 `access.py`로 판단한다. 볼 수 없으면 404(원칙 II).
5. 화면이 받은 값을 그린다. 제목 · 닉네임 · 댓글은 `escapeHTML`/`textContent`, 본문만 서버가 정제한 HTML을 넣는다(원칙 III).
6. 조회는 `POST /api/blogs/minju/posts/3/views`로 따로 남긴다(30분 중복 제외). 공감 · 댓글 · 이웃 맺기도 API로 보낸다.

### 글 발행 한 번의 흐름 (POST-01, COM-P06)

1. 글쓰기 화면이 일회용 `client_token`을 만든다. 저장하지 않고 나가려 하면 경고한다.
2. 발행을 누르면 화면이 제목 → 본문 순서로 먼저 확인하고 `POST /api/blogs/{address}/posts`를 보낸다.
3. 서버: serializer 검증 → nh3 정제 → 요약 · 첫 사진. 한 트랜잭션에서 블로그 행 잠금 → `last_post_no + 1` → 저장(`(blog_id, client_token)` 유일) → 태그 · 사진 연결.
4. 같은 토큰이 이미 있으면 그 기록을 돌려준다. 성공하면 `201 {no, url}`, 화면이 기록 화면으로 간다.
5. 실패하면 화면이 첫 번째 오류를 보이고 입력한 내용은 그대로 둔다(COM-02a).

임시저장(POST-11)은 `/api/blogs/{address}/drafts`로 번호 없이 `DRAFT`로 두고, 발행할 때 위 3단계를 거쳐 번호를 받는다.

### 보안 기본값 (원칙 III)

- 운영: `DEBUG=False`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, `SECURE_HSTS_SECONDS`(30일), `SECURE_PROXY_SSL_HEADER`(nginx 뒤)
- 세션: 브라우저를 닫으면 끝나고, 마지막 사용에서 2주가 지나면 서버가 끝낸다
- CSRF: 화면이 `csrftoken` 쿠키를 읽어 `X-CSRFToken` 헤더로 보낸다. 소셜 로그인 시작은 POST 폼
- 요청 횟수 제한: 로그인 · 가입 · 쓰기 API마다 `throttle_scope`
- 로그인 실패 제한(research 14절), 비밀번호 Argon2, 재설정 요청은 가입 여부와 관계없이 같은 안내
- 로그 · 오류 응답에 비밀번호 · 토큰 · 세션 값 · 개인 정보를 남기지 않는다(AUTH-01b, COM-P05). 공개 저장소의 Actions 로그는 개수만
- `next` 파라미터는 같은 사이트 주소만 허용(열린 리디렉션 방지, `safeNext`)

### 테스트 구성 (원칙 V)

`cd backend && python manage.py test apps` 하나로 모두 돈다.

| 종류 | 무엇을 | 어디에 |
| --- | --- | --- |
| 권한 | 비회원 · 회원 · 주인 · 관리자로 API를 직접 불러 막히는지(SC-004) | 앱마다 `test_*.py` |
| 공개 범위 | 나만 보기 · 이웃 공개 · 숨김 · 임시저장 · 허문 한채가 목록 · 검색 · 마을 · 골목 · 순위 · 이웃 소식 · 개수 · 직접 주소에 나오지 않는지(SC-003) | `posts/test_*`, `community/test_*` |
| 중복 처리 | 발행 · 댓글 · 공감 · 이웃 연속 요청, 글 번호(SC-005) | `posts/test_api.py` 등 |
| 정제 | 스크립트 · 이벤트 속성 · `javascript:` 링크(SC-010) | `posts/test_hardening.py` 등 |
| 탈퇴 · 허물기 | 지우는 것 · 남는 것, 파일 정리 | `accounts/test_leave.py`, `blogs/test_demolish.py` |
| 화면 | 바꾼 JS 문법 확인, PR 체크리스트로 브라우저 확인 | PR마다 |

### 단계별 범위

| 단계 | 사용자 이야기 | 만들어지는 것 |
| --- | --- | --- |
| 기반 | — | 프로젝트 골격, 설정, Docker, User 모델, 마이그레이션, 주제 10개, 공통 화면 · 오류 화면, 테스트 환경 |
| P1 | 1~6 | 가입 · 로그인 · 동의 · 개설, 글쓰기 · 수정 · 삭제, 블로그 메인 · 카테고리 · 태그 · 블로그 검색, 홈 최신 글, 댓글 · 공감, 권한 · 오류 화면 · 관리자 계정 |
| P2 | 7~11 | 조회수 · 정각 인기 글, 주제 · 통합 검색, 임시저장 · 대표 이미지 · 하위 카테고리 · 순서 · 이전/다음 글 · 태그 모아 보기 · 주소 복사, 구독 · 피드, 글 · 댓글 관리, 댓글 수정(CMT-03), 방명록, 로그인 유지, 프로필 수정, 이용 제한 · 숨김 |
| P3 | 12 | 인기 블로거 · 랭킹 전체보기, 예약 발행, 답글 · 비밀댓글 · 댓글 허용, 저장, 알림, 맞구독, 추천 블로그, 블로그 꾸미기 · 삭제, 카테고리 비공개, 태그 관리, 방문 통계, 차단 · 금칙어, 신고, 블로그 이용 제한, 공지 · 이력 · 대시보드, 탈퇴 |

### 확정한 값

통합본이 '자율'로 둔 값(이미지 10MB, 조회 중복 30분, 로그인 실패 5분 5회 등)과 주제 slug는 [research.md](./research.md) 14·15절에 있다. 로그인 유지는 2026-10-22에 '브라우저를 닫으면 로그아웃, 서버 쪽 2주'로 바꿨다. 홈 영역별 노출 개수는 잠정값이며 홈 디자인 후 다시 정한다.

## 남은 확인 사항

- **CSP 헤더**: 처음 판은 CSP 미들웨어를 계획했지만 아직 없다. 화면에 인라인 스크립트가 거의 없어(500.html의 `onclick` 하나) 붙이기 쉽다. 붙이면 원칙 III를 한 겹 더 지킨다.
- **브라우저 E2E**: SC-008(360px) · SC-009(크로미움 · 웹킷)를 자동으로 확인하는 테스트가 없다. 지금은 PR 체크리스트로 사람이 확인한다.
- **JavaScript가 꺼진 방문 · 검색 로봇**: 화면이 JS로 그려져 JS 없이는 내용이 보이지 않는다. 검색 노출이 필요해지면 기록 화면만 서버가 그리는 방안을 따로 정한다.
- **서브도메인 주소**: 와일드카드 DNS · 인증서가 생기면 `HANCHAE_DOMAIN`을 넣고 연다.
- **SC-006(5분) · SC-007(2초, 90%)**: spec이 가정한 값이다.
- **문서 맞추기**: `contracts/pages.md` · `contracts/api.md` · `research.md` · `tasks.md`는 처음 판 기준이다. 지금 화면 주소는 이 문서, API는 `docs/API명세서.md`가 기준이다.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| 원칙 III "GET으로 상태를 바꾸지 않는다": 순위 API의 그 시간 첫 `GET`이 순위 스냅숏을 계산해 저장한다 | 학교 서버에 정각마다 도는 작업(cron)을 둘 수 없다. 첫 요청이 직전 정각 기준으로 계산하면 결과는 '매 정각 계산'과 같다 | GitHub Actions 예약 실행은 몇 분씩 늦게 돌 수 있어 SC-006(5분)을 지키기 어렵다. 저장은 정각마다 한 번이고(유일 키), 같은 GET을 반복해도 결과가 같으며(멱등) 사용자 데이터는 바꾸지 않는다 |
| 원칙 IV CHECK 일부를 앱이 지킴: `hidden_by_id` 있음, 순위 항목은 글·블로그 중 하나 | MySQL은 `ON DELETE` 동작이 걸린 외래 키 열을 CHECK에 쓰지 못한다(data-model 9절) | 외래 키 동작을 없애면 관리자·글 삭제 때 행이 남거나 삭제가 막힌다. 서비스 함수와 테스트로 지킨다 |

처음 판에 있던 '글 상세 GET이 조회 기록을 쓴다'는 화면 방식이 바뀌어 조회를 `POST …/views`로 따로 남기게 되면서 없어졌다.
