# Implementation Plan: 한채 블로그 플랫폼

**Branch**: `001-blog` (작업 브랜치 `claude/spec-kit-plan-4r6mq0`) | **Date**: 2026-10-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-blog/spec.md`

## Summary

티스토리처럼 회원마다 블로그 하나를 열어 글을 쓰고, 홈·검색·구독으로 다른 블로그의 글을 발견하고, 댓글·공감으로 소통하는 서비스를 만든다.

민주가 정한 **HTML·CSS·JavaScript + Python** 위에서, 서버가 HTML을 만들어 보내는 **Django 5.2 LTS** 웹 앱 하나로 만든다. 데이터는 팀 ERD 컨벤션대로 **MySQL 8.4**, 이메일·카카오·구글·네이버 로그인은 **django-allauth**, WYSIWYG 에디터는 **Quill 2**, 정각 인기 글 집계는 **cron이 실행하는 관리 명령**이다. 배포는 리눅스 서버 한 대에 Docker Compose로 올린다. 각 선택의 이유와 대안은 [research.md](./research.md)에 있다.

구현 순서는 spec 우선순위를 따른다. **P1(이야기 1~6)만으로 "가입 → 개설 → 발행 → 홈에서 발견 → 읽기·댓글·공감" 한 바퀴가 돌게** 먼저 만들고, P2·P3를 이야기 단위로 더한다.

## Technical Context

**Language/Version**: Python 3.13 (백엔드), HTML5·CSS3·JavaScript ES2022 모듈 (프론트엔드, 빌드 없음)
**Primary Dependencies**: Django 5.2 LTS, django-allauth 65.x(이메일 + kakao·google·naver), mysqlclient, nh3(HTML 정리), Pillow(이미지 검증), argon2-cffi, django-csp, Gunicorn, Quill 2(정적 파일로 포함)
**Storage**: MySQL 8.4 LTS(`utf8mb4_0900_ai_ci`, ngram 전문 검색). 이미지는 서버 디스크(`MEDIA_ROOT`)
**Testing**: pytest + pytest-django, factory_boy, Playwright for Python(크로미움·웹킷, 360px), ruff
**Target Platform**: 리눅스 서버 1대(Docker Compose: Caddy + Gunicorn/Django + MySQL), 사용자는 최신 크롬·사파리·엣지(SC-009)
**Project Type**: 웹 애플리케이션 (서버 렌더링 단일 Django 프로젝트)
**Performance Goals**: 글 목록·상세 첫 화면 2초 안(SC-007), 정각 후 5분 안 순위 갱신(SC-006). 서버 응답은 p95 300ms 이하를 목표로 한다
**Constraints**: 비공개·숨김 글 노출 0건(SC-003), 권한표 ✕ 칸 100% 거부(SC-004), 중복 생성 0건(SC-005), 스크립트 실행 0건(SC-010), 360px 가로 스크롤 없음(SC-008), 한국 시간 표시(FR-118)
**Scale/Scope**: 첫해 가정 회원 1천 명, 블로그 수백 개, 글 1만 개, 동시 접속 100명 이하. 화면 약 30개, FR 80여 개(P1 약 50개)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

이 저장소에는 아직 `/speckit.constitution`으로 만든 프로젝트 원칙 문서(`.specify/memory/constitution.md`)가 없다. 그래서 spec의 공통 정책과 성공 기준에서 어겨서는 안 되는 것을 골라 임시 관문으로 쓴다. 원칙 문서를 만들면 이 절을 그 기준으로 다시 확인한다.

| 관문 | 근거 | Phase 0 전 | Phase 1 후 |
| --- | --- | --- | --- |
| G1. 권한은 서버가 지킨다. 버튼 숨김은 보조일 뿐 | FR-110, SC-004 | ✅ 데코레이터 + 권한표 매개변수 테스트로 설계 | ✅ [pages.md](./contracts/pages.md) 모든 주소에 권한 명시 |
| G2. 공개 범위 판단은 한 곳에서만 | FR-028, FR-031, SC-003 | ✅ `posts/policy.py` 하나로 결정 | ✅ [data-model.md](./data-model.md) "볼 수 있는 글", 순위도 읽을 때 재확인 |
| G3. 사용자 입력은 실행되지 않는다 | FR-116, SC-010 | ✅ 템플릿 자동 이스케이프 + nh3 + CSP | ✅ 본문 허용 목록 확정(research 5절) |
| G4. 연타·실패에도 데이터가 어긋나지 않는다 | FR-117, SC-005 | ✅ 일회용 토큰, PUT/DELETE 상태 API, 수치 실시간 계산 | ✅ [api.md](./contracts/api.md) 멱등성 규칙 |
| G5. 휴대폰 화면에서 P1 전부 | FR-118, SC-008 | ✅ 모바일 우선 CSS | ✅ quickstart 6절에 360px 확인 |
| G6. 단순함: 서비스·도구는 필요할 때만 늘린다 | 민주 개인 명세 1.5 | ✅ 웹 앱 1개 + DB 1개, 작업 큐·검색 엔진·SPA 없음 | ✅ 추가 없음 |

위반 없음. Complexity Tracking은 비워 둔다.

## Project Structure

### Documentation (this feature)

```text
specs/001-blog/
├── spec.md              # 기능 명세 (/speckit.specify, /speckit.clarify)
├── plan.md              # 이 문서 (/speckit.plan)
├── research.md          # Phase 0: 기술 결정, 자율 값, 주제 목록
├── data-model.md        # Phase 1: 모델·관계·상태·삭제 규칙
├── quickstart.md        # Phase 1: 로컬 실행과 P1 확인 순서
├── contracts/
│   ├── pages.md         # Phase 1: HTML 화면 주소와 권한
│   └── api.md           # Phase 1: JSON API
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2: /speckit.tasks가 만든다 (아직 없음)
```

### Source Code (repository root)

코드는 이 저장소 루트에 둔다. Spec Kit은 명세(`specs/`)와 코드를 한 저장소에서 다루는 것을 전제로 하므로, 저장소 이름이 `blog-docs`이지만 그대로 쓴다(이름은 나중에 바꿔도 된다).

```text
manage.py
pyproject.toml                # 의존성, ruff·pytest 설정 (uv)
.env.example
docker-compose.yml            # db(MySQL 8.4), mailpit, web, caddy
config/
├── settings/
│   ├── base.py               # 공통 (TIME_ZONE=Asia/Seoul, allauth, CSP, 업로드 상한)
│   ├── dev.py
│   └── prod.py               # DEBUG=False, 보안 쿠키, SMTP
├── urls.py                   # 서비스 경로 먼저, 마지막에 /{blog}/ 경로
└── wsgi.py
apps/
├── core/                     # 공통: 권한 데코레이터, 오류 화면, 페이지·커서, 일회용 토큰, HTML 정리(nh3), 시간 표시
├── accounts/                 # User 모델, allauth 어댑터(FR-001d), 내 정보, 탈퇴, 이용 제한 확인 미들웨어, create_service_admin 명령
├── blogs/                    # Blog, 예약어, 개설·설정, 사이드바, 블로그 메인, 방명록
├── posts/                    # Post·Category·Tag·Topic·Image·PostView, policy.py(볼 수 있는 글), 글쓰기·상세·목록·블로그 내 검색, 이미지 업로드
├── comments/                 # Comment, 댓글 API
├── social/                   # PostLike·Subscription(·저장·알림 P3), 피드
├── discovery/                # 홈, 주제별 글, 통합 검색, RankingSnapshot, compute_rankings 명령
└── moderation/               # UserSanction, AdminLog, 숨김, 서비스 관리 화면 (신고·공지 P3)
templates/
├── base.html                 # 헤더(로고·검색창·로그인), 푸터
├── blog_base.html            # 블로그 화면 공통 + 사이드바
├── errors/{403,404,500}.html
└── {앱 이름}/...
static/
├── css/                      # tokens.css(색·글꼴 변수), base.css, blog.css, editor.css
├── js/                       # api.js(fetch + CSRF + 401 처리), editor.js, like.js, comments.js, load-more.js, drawer.js
└── vendor/quill/
tests/
├── unit/                     # 정책·검증 함수
├── integration/              # 화면·API (Django test client), 권한표 매개변수 테스트
└── e2e/                      # Playwright: P1 흐름, 360px
deploy/
├── Caddyfile
├── crontab                   # 0 * * * * compute_rankings / * * * * * publish_scheduled_posts(P3)
└── backup.sh
```

**Structure Decision**: Django 프로젝트 하나에 도메인별 앱 8개를 둔다. 프론트엔드는 별도 프로젝트 없이 `templates/`와 `static/`에 있다. `/{blog}` 경로가 다른 모든 서비스 경로 뒤에 오도록 `config/urls.py` 맨 끝에 붙이고, 서비스 경로 첫 단어는 모두 블로그 주소 예약어에 넣는다([pages.md](./contracts/pages.md) 끝).

## 핵심 설계

### 화면과 주소

민주 개인 명세 6.2의 SCR-01~20을 그대로 쓰고 주소를 확정했다. 전체 목록과 권한은 [contracts/pages.md](./contracts/pages.md).

- 서비스: `/`, `/search`, `/topic/{slug}`, `/ranking`, `/feed`
- 회원: `/accounts/...`(allauth), `/me`, `/blog/new`
- 블로그 관리: `/manage/write`, `/manage/posts`, `/manage/comments`, `/manage/categories`, `/manage/settings` — 주소에 블로그가 없고 항상 "내 블로그"다
- 블로그: `/{blog}`, `/{blog}/{id}`, `/{blog}/category/{name}`, `/{blog}/tag/{name}`, `/{blog}/search`, `/{blog}/guestbook`
- 서비스 관리: `/admin/...` (Django 기본 관리 도구는 운영자용 `/django-admin/`)

### 요청 한 번의 흐름 (글 상세 예)

1. `config/urls.py`가 `/{blog}/{id}`를 `posts.views.post_detail`로 보낸다.
2. 미들웨어가 로그인 회원의 이용 제한을 확인한다(제한 중이면 로그아웃 + 안내).
3. 뷰가 `get_viewable_post_or_404(blog, id, viewer)`를 부른다. FR-028 순서로 판단하고 볼 수 없으면 404.
4. 조회 기록을 남긴다(30분 중복 제외, research 8절).
5. 템플릿이 정리된 본문 HTML(`|safe`는 이 필드 하나만)과 나머지 자동 이스케이프 값을 그린다.
6. 공감·댓글 버튼은 `static/js/`가 [api.md](./contracts/api.md) API로 처리한다. JS가 없어도 댓글은 폼 전송으로 된다.

### 보안 기본값

- `DEBUG=False`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, `SECURE_HSTS_SECONDS`, `X_FRAME_OPTIONS=DENY`
- CSP: `default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'`(Quill 인라인 스타일). 인라인 `<script>` 금지
- 로그인 시도 제한(allauth rate limit), 비밀번호 Argon2, 재설정 메일은 가입 여부와 관계없이 같은 안내
- 로그·오류 화면에 비밀번호·토큰을 남기지 않는다(FR-001b, FR-116)

### 단계별 범위

| 단계 | 사용자 이야기 | 만들어지는 것 |
| --- | --- | --- |
| 기반 | — | 프로젝트 골격, 설정, Docker Compose, User 모델, 공통 레이아웃·오류 화면, 테스트 환경 |
| P1 | 1~6 | 가입·로그인·개설, 글쓰기(Quill·이미지), 블로그 메인·카테고리·태그·블로그 검색, 홈 최신 글, 댓글·공감, 권한·관리자 계정 |
| P2 | 7~11 | 조회수·정각 순위, 주제·통합 검색, 임시저장·대표 이미지·하위 카테고리·이전/다음 글, 구독·피드, 글·댓글 관리, 방명록, 이용 제한·숨김 |
| P3 | 12 | 인기 블로거·랭킹 전체보기, 예약 발행, 답글·비밀댓글, 저장, 알림, 신고, 탈퇴, 블로그 삭제·꾸미기, 통계 등 |

데이터 모델은 P1·P2 테이블을 처음부터 만들고, P3 전용 테이블은 해당 기능을 만들 때 더한다([data-model.md](./data-model.md) 6절).

### 확정한 값

통합본이 '자율'로 둔 값(이미지 10MB, 로그인 유지 14일, 조회 중복 30분 등)과 **주제 목록 10개**(일상, 여행·맛집, IT·개발, 문화·연예, 책·영화, 반려동물, 요리, 스포츠, 경제·재테크, 기타)는 [research.md](./research.md) 14·15절에 있다. 홈 영역별 노출 개수는 잠정값이며 홈 디자인 후 다시 정한다.

## Complexity Tracking

관문 위반이 없어 비워 둔다.

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| — | — | — |

## 다음 단계

`/speckit.tasks`로 이 plan을 바탕으로 작업 목록(`tasks.md`)을 만든다. 작업은 기반 → P1 이야기 1~6 → P2 → P3 순서로, 이야기마다 혼자 구현·시연할 수 있게 나눈다.
