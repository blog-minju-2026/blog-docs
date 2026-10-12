---

description: "한채 블로그 플랫폼 구현 작업 목록"
---

# Tasks: 한채 블로그 플랫폼

**Input**: `specs/001-blog/`의 설계 문서

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/pages.md](./contracts/pages.md), [contracts/api.md](./contracts/api.md), [quickstart.md](./quickstart.md)

> 이 문서는 2026-10-08에 plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md와 constitution v1.0.0을 바탕으로 `/speckit.tasks`가 만들었다. 설계 문서가 바뀌면 이 목록도 함께 고친다.

**Tests**: constitution 원칙 V에 따라 테스트는 **필수**다. 수용 시나리오(`US2-8` 등)마다 테스트를 하나 이상 두고, 테스트마다 `@pytest.mark.req("<ID>")`를 단다. 권한·공개 범위·중복 처리 테스트는 구현보다 먼저 쓰고, **실패하는 것을 확인한 뒤** 구현한다.

**Organization**: 작업은 사용자 이야기별로 묶었다. 이야기 하나만 끝내도 혼자 시연하고 테스트할 수 있다.

## Format: `[ID] [P?] [Story] 설명`

- **[P]**: 함께 진행할 수 있다(다른 파일이고, 끝나지 않은 작업에 기대지 않는다)
- **[Story]**: 이 작업이 속한 사용자 이야기(US1, US2 …). 기반·마무리 단계에는 붙이지 않는다
- 설명에는 정확한 파일 경로를 적고, 끝 괄호에 요구사항 ID(원칙 I)를 적는다

## Path Conventions

- plan.md '프로젝트 구조'를 따른다. 코드는 저장소 루트에 둔다.
- 앱: `apps/core`, `apps/accounts`, `apps/blogs`, `apps/posts`, `apps/comments`, `apps/social`, `apps/discovery`, `apps/moderation`
- 화면: `templates/`, `static/css/`, `static/js/`, `static/vendor/quill/`
- 테스트: `tests/unit/`, `tests/integration/`, `tests/permissions/`, `tests/e2e/`
- 설정: `config/settings/{base,dev,prod}.py`, 운영: `deploy/`

---

## Phase 1: Setup (공통 기반 준비)

**Purpose**: 프로젝트를 만들고 도구를 갖춘다

- [ ] T001 `pyproject.toml`을 uv로 만든다. Python 3.13, Django 5.2 LTS, django-allauth 65.x, mysqlclient, nh3, Pillow, argon2-cffi, gunicorn, 개발용 pytest·pytest-django·pytest-playwright·ruff. ruff·pytest 설정(`DJANGO_SETTINGS_MODULE`, `req` 표시 등록)도 여기 둔다. `uv.lock`을 함께 커밋한다 in pyproject.toml (원칙 VI)
- [ ] T002 `manage.py`, `config/__init__.py`, `config/wsgi.py`, `config/urls.py` 빈 골격과 앱 8개(`apps/core`, `apps/accounts`, `apps/blogs`, `apps/posts`, `apps/comments`, `apps/social`, `apps/discovery`, `apps/moderation`)의 `apps.py`·`__init__.py`를 만든다 in apps/ (원칙 VI)
- [ ] T003 [P] 비밀 값 이름만 적은 `.env.example`(DB 비밀번호, `SECRET_KEY`, `KAKAO_CLIENT_ID`·`KAKAO_SECRET`, `GOOGLE_CLIENT_ID`·`GOOGLE_SECRET`, `NAVER_CLIENT_ID`·`NAVER_SECRET`, SMTP)과 `.env`를 빼는 `.gitignore`를 만든다 in .env.example (원칙 III)
- [ ] T004 [P] `docker-compose.yml`에 `db`(MySQL 8.4, `--character-set-server=utf8mb4 --collation-server=utf8mb4_0900_as_ci`, 데이터 볼륨), `mailpit`(웹 8025, SMTP 1025), `web`(Gunicorn + Django, 미디어 볼륨), `caddy`를 둔다. Gunicorn `--access-logformat`은 경로 대신 키를 가린 값을 쓴다 in docker-compose.yml (COM-P06, 원칙 IV)
- [ ] T005 [P] `deploy/Caddyfile`을 만든다. HTTPS 자동 발급, `/static/`·`/media/` 직접 제공, 나머지는 `web`으로. 접근 로그 `log` 필터로 `/accounts/confirm-email/{key}/`와 `/accounts/password/reset/key/{key}/`의 키 부분을 `***`로 바꿔 기록한다(research 16절) in deploy/Caddyfile (AUTH-01b, COM-P05, 원칙 III)
- [ ] T006 [P] `Makefile`에 `make test`를 만든다. `uv run ruff check .` → `uv run pytest`(단위·통합·권한표) → `uv run pytest tests/e2e --browser chromium --browser webkit`을 차례로 돌리고 하나라도 실패하면 멈춘다 in Makefile (원칙 V)
- [ ] T007 [P] Quill 2 배포 파일을 `static/vendor/quill/`에 넣고(빌드 없음), 색·글꼴 변수 `static/css/tokens.css`를 만든다 in static/vendor/quill/ (POST-01b, 원칙 VI)
- [ ] T008 [P] `deploy/crontab`(`30 4 * * * cleanup`; 정각 집계 줄은 US7에서 더한다)과 매일 `mysqldump` + 이미지 폴더를 복사하고 14일치를 남기는 `deploy/backup.sh`를 만든다 in deploy/backup.sh (COM-P06)

---

## Phase 2: Foundational (모든 이야기의 전제)

**Purpose**: 설정, 모든 P1·P2 테이블, 공개 범위 한 곳, 권한 데코레이터, 공통 화면, 테스트 환경. 이것이 끝나기 전에는 어떤 이야기도 시작하지 않는다

**⚠️ CRITICAL**: P3 전용 테이블·열(`post_saves`, `notifications`, `reports`, `blog_blocked_users`, `blog_banned_words`, `visit_stats`, `notices`, data-model 1.2절의 추가 열)은 여기서 만들지 않는다(원칙 VI)

### 설정과 테스트 환경

- [ ] T009 `config/settings/base.py`를 만든다. `TIME_ZONE="Asia/Seoul"`, `USE_TZ=True`, `LANGUAGE_CODE="ko-kr"`, DB `OPTIONS={"charset": "utf8mb4"}`·테스트 DB `COLLATION="utf8mb4_0900_as_ci"`, `AUTH_USER_MODEL="accounts.User"`, `PASSWORD_HASHERS` 맨 앞 Argon2, DB 캐시(`createcachetable`), `DATA_UPLOAD_MAX_MEMORY_SIZE`·이미지 10MB·글당 이미지 50장·본문 1MB·카테고리 100개·검색어 100자·댓글 10초 간격 같은 research 14절 값, `INSTALLED_APPS`에 앱 8개와 allauth in config/settings/base.py (COM-P07, COM-P03, 원칙 III)
- [ ] T010 [P] `config/settings/dev.py`(DEBUG, Mailpit SMTP `localhost:1025`)와 `config/settings/prod.py`(`DEBUG=False`, `SESSION_COOKIE_SECURE`, `CSRF_COOKIE_SECURE`, `SECURE_HSTS_SECONDS`, `X_FRAME_OPTIONS="DENY"`, `SECURE_CONTENT_TYPE_NOSNIFF`, `ADMINS` 500 메일, 운영 SMTP, 요청 본문을 로그에 남기지 않음)를 만든다 in config/settings/prod.py (COM-P05, COM-02a, 원칙 III)
- [ ] T011 `tests/conftest.py`를 만든다. MySQL 8.4 테스트 DB, 사용자 상태 픽스처 4종(`anonymous`, `member`, `blog_owner`, `service_admin`), 글·블로그 만들기 픽스처 함수, `--req <ID>` 옵션(그 `@pytest.mark.req` 값이 붙은 테스트만 고른다) in tests/conftest.py (원칙 V)
- [ ] T012 [P] `--req` 옵션이 `req` 표시로 테스트를 고르고, 표시 없는 테스트가 있으면 경고하는지 확인하는 테스트를 쓴다 in tests/unit/test_req_option.py (원칙 I, 원칙 V)

### 테이블 (테스트 먼저)

> **NOTE: 아래 스키마·공개 범위·권한표 테스트를 먼저 쓰고, 모델이 없어 실패하는 것을 확인한다**

- [ ] T013 [P] data-model 9절 표의 DB 제약을 하나씩 시도하는 테스트를 쓴다: `users.email` UK, `users.nickname` UK(대소문자만 다른 값도 겹침), `blogs.active_owner_id` UK(삭제된 블로그끼리는 겹치지 않음), `blogs.address` UK, `(blog_id, post_no)` UK, `(blog_id, client_token)` UK, `(blog_id, parent_key, name)` UK, `categories.parent_id` RESTRICT, `tags (blog_id, name)` UK(`Travel` = `travel`), `post_tags` 복합 PK, `(user_id, post_id)` UK, `(subscriber_id, blog_id)` UK, 댓글·방명록 `(author_id, client_token)` UK, `(kind, window_end)` UK, `(snapshot_id, position)` UK, CHECK `ck_posts_published_fields`·`ck_*_hidden_reason`·`ck_ranking_snapshots_kind`·`ck_ranking_snapshots_basis`·`ck_user_sanctions_period` in tests/unit/test_schema_constraints.py (원칙 IV, SC-005)
- [ ] T014 [P] P3 전용 테이블(`post_saves`, `notifications`, `reports`, `blog_blocked_users`, `blog_banned_words`, `visit_stats`, `notices`)과 P3 열(`posts.scheduled_at`, `posts.is_comment_allowed`, `categories.is_private`, `comments.parent_id`·`is_secret`·`deleted_at`, `blogs.skin`·`header_image_id`·`restricted_at`)이 아직 없는지 확인하는 테스트를 쓴다. US12 작업이 하나씩 더할 때 이 목록에서 뺀다 in tests/unit/test_no_p3_schema.py (원칙 VI)
- [ ] T015 [P] 주제 10개가 research 15절 순서·slug(`daily`, `travel-food`, `it-dev`, `culture`, `books-movies`, `pets`, `cooking`, `sports`, `finance`, `etc`)대로 들어 있는지 확인하는 테스트를 쓴다 in tests/unit/test_topics_seed.py (POST-11)
- [ ] T016 `apps/accounts/models.py`에 `User(AbstractBaseUser, PermissionsMixin)`와 `UserManager`를 만든다. `db_table="users"`. `email` VARCHAR(254) UK null "이메일 가입자는 필수. 소셜 가입자는 제공사가 준 경우만. 소문자로 바꿔 저장", `password` VARCHAR(128) "Argon2 해시. 소셜 전용 회원은 '사용 불가' 값", `nickname` VARCHAR(20) UK null "앞뒤 공백 뺀 2~20자, 겹칠 수 없음. 탈퇴하면 null로 풀어 준다", `profile_image` VARCHAR(255) null "회원 프로필 파일 경로(Django `ImageField`)", `role` VARCHAR(10) "`MEMBER` \| `ADMIN`. 기본 `MEMBER`", `terms_agreed_at` DATETIME, `privacy_agreed_at` DATETIME, `is_active` BOOL, `is_staff` BOOL "기본 false", `is_superuser` BOOL "기본 false", `last_login` DATETIME null, `created_at`, `updated_at`. `withdrawn_at`은 P3에서 더한다. 이메일이 없는 소셜 회원이 있으므로 `USERNAME_FIELD="email"`이어도 null을 허용한다 in apps/accounts/models.py (AUTH-01, AUTH-01f, AUTH-01i, AUTH-05, ADMIN-01)
- [ ] T017 `User` 모델을 다른 어떤 앱보다 먼저 첫 마이그레이션으로 만든다(나중에 바꾸기 어렵다) in apps/accounts/migrations/0001_initial.py (원칙 IV)
- [ ] T018 [P] `apps/blogs/models.py`에 `Blog`(`db_table="blogs"`)와 `GuestbookEntry`(`db_table="guestbook_entries"`)를 만든다. `Blog`: `owner` FK → users (PROTECT), `address` VARCHAR(32) UK "영문 소문자·숫자·하이픈 4~32자, 하이픈으로 시작·끝 불가, 예약어 불가. 바꿀 수 없음", `name` VARCHAR(40) "1~40자", `description` VARCHAR(200) "0~200자", `profile_image` VARCHAR(255) null, `last_post_no` INT UNSIGNED "기본 0", `deleted_at` DATETIME null, `active_owner_id` = `GeneratedField(IF(deleted_at IS NULL, owner_id, NULL), STORED)` UK null. `GuestbookEntry`: `blog` FK (CASCADE), `author` FK → users (PROTECT), `content` TEXT "1~1,000자, 순수 텍스트", `edited_at` DATETIME null, `hidden_at` DATETIME null, `hidden_reason` VARCHAR(200) null, `hidden_by` FK → users null (SET_NULL), `client_token` CHAR(36) null, UK `(author_id, client_token)`, CHECK `ck_guestbook_entries_hidden_reason`: `hidden_at IS NULL OR hidden_reason IS NOT NULL`, 정렬 `created_at DESC, id DESC` in apps/blogs/models.py (BLOG-01, BLOG-01a, BLOG-01b, BLOG-01d, BLOG-02, POST-01d, CMT-04)
- [ ] T019 [P] `apps/posts/models.py`에 `Topic`, `Category`, `Tag`, `Post`, `PostTag`, `Image`, `PostImage`, `PostView`를 만든다. `topics`: `name` VARCHAR(20) UK, `slug` VARCHAR(30) UK, `sort_order` SMALLINT. `categories`: `blog` FK (CASCADE), `parent` FK → categories null (RESTRICT), `name` VARCHAR(20) "앞뒤 공백 뺀 1~20자", `sort_order` INT, `parent_key` = `GeneratedField(IFNULL(parent_id, 0), STORED)`, UK `(blog_id, parent_key, name)`. `tags`: `blog` FK (CASCADE), `name` VARCHAR(20) "앞뒤 공백과 맨 앞 `#`을 뺀 1~20자", UK `(blog_id, name)`. `posts`: `blog` FK (CASCADE), `post_no` INT UNSIGNED null, `category` FK null (SET_NULL), `topic` FK null (SET_NULL), `title` VARCHAR(100), `content` LONGTEXT, `content_text` LONGTEXT, `excerpt` VARCHAR(150), `cover_image` FK → images null (SET_NULL), `first_image` FK → images null (SET_NULL), `status` VARCHAR(10) "`DRAFT` \| `PUBLISHED`", `visibility` VARCHAR(10) "`PUBLIC` \| `PRIVATE`. 기본 `PUBLIC`", `published_at` DATETIME null, `ever_public` BOOL, `view_count` INT UNSIGNED "기본 0", `hidden_at` DATETIME null, `hidden_reason` VARCHAR(200) null, `hidden_by` FK → users null, `client_token` CHAR(36) null, UK `(blog_id, post_no)`, UK `(blog_id, client_token)`, 인덱스 `(blog_id, status, published_at, id)`·`(status, visibility, published_at, id)`·`(topic_id, published_at, id)`·`(category_id, published_at, id)`, CHECK `ck_posts_published_fields`: `status = 'DRAFT' OR (post_no IS NOT NULL AND published_at IS NOT NULL)`, CHECK `ck_posts_hidden_reason`. `post_tags`: `(post_id, tag_id)` 복합 PK. `images`: `uploader` FK → users null (SET_NULL), `file` VARCHAR(255) "이름은 UUID", `thumb_file` VARCHAR(255) "목록용 가로 480px", `content_type` VARCHAR(20) "`image/jpeg` \| `image/png` \| `image/gif` \| `image/webp`", `width`·`height` INT, `size_bytes` INT "10MB 이하". `post_images`: `(post_id, image_id)` 복합 PK, 양쪽 CASCADE. `post_views`: `post` FK (CASCADE), `viewer_key` CHAR(64), `viewed_at` DATETIME, 인덱스 `(post_id, viewer_key, viewed_at)`·`(viewed_at, post_id)` in apps/posts/models.py (POST-01, POST-01a, POST-01d, POST-05, POST-06, POST-07, POST-09, POST-11, CAT-01, CAT-02, CAT-03, CAT-04, TAG-01, COM-P02, COM-P03, COM-P06)
- [ ] T020 [P] `apps/comments/models.py`에 `Comment`(`db_table="comments"`)를 만든다. `post` FK (CASCADE), `author` FK → users (PROTECT), `content` TEXT "앞뒤 공백 뺀 1~1,000자. 순수 텍스트로 저장", `edited_at` DATETIME null, `hidden_at` DATETIME null, `hidden_reason` VARCHAR(200) null, `hidden_by` FK → users null, `client_token` CHAR(36) null, UK `(author_id, client_token)`, CHECK `ck_comments_hidden_reason`, 정렬 `created_at, id` 오름차순 in apps/comments/models.py (CMT-01, CMT-02, CMT-03, COM-P06)
- [ ] T021 [P] `apps/social/models.py`에 `PostLike`(`db_table="post_likes"`: `user` FK (CASCADE), `post` FK (CASCADE), UK `(user_id, post_id)`)와 `Subscription`(`db_table="subscriptions"`: `subscriber` FK (CASCADE), `blog` FK (CASCADE), UK `(subscriber_id, blog_id)`)을 만든다 in apps/social/models.py (SOC-01, SUB-01, COM-P06)
- [ ] T022 [P] `apps/discovery/models.py`에 `RankingSnapshot`(`db_table="ranking_snapshots"`: `kind` VARCHAR(10) "`POST` \| `BLOGGER`", `window_end` DATETIME, `basis` VARCHAR(5) "`1H` \| `24H` \| `EMPTY`", UK `(kind, window_end)`, CHECK `ck_ranking_snapshots_kind`·`ck_ranking_snapshots_basis`)와 `RankingEntry`(`db_table="ranking_entries"`: `snapshot` FK (CASCADE), `position` SMALLINT "순위, 1부터", `post` FK → posts null (CASCADE), `blog` FK → blogs null (CASCADE, P3 전까지 비워 둠), `score` INT, UK `(snapshot_id, position)`)를 만든다. `rank`라는 이름은 쓰지 않는다 in apps/discovery/models.py (HOME-02)
- [ ] T023 [P] `apps/moderation/models.py`에 `UserSanction`(`db_table="user_sanctions"`: `user` FK (PROTECT), `admin` FK (PROTECT), `reason` VARCHAR(500) "필수", `starts_at` DATETIME, `ends_at` DATETIME null "null이면 영구", `released_at` DATETIME null, `released_by` FK null, CHECK `ck_user_sanctions_period`: `ends_at IS NULL OR ends_at > starts_at`)와 `AdminLog`(`db_table="admin_logs"`: `admin` FK (PROTECT), `action` VARCHAR(30) "`HIDE_POST` `UNHIDE_POST` `HIDE_COMMENT` `UNHIDE_COMMENT` `HIDE_GUESTBOOK` `UNHIDE_GUESTBOOK` `SANCTION_USER` `RELEASE_USER`", `target_type` VARCHAR(20) "post \| comment \| guestbook \| user", `target_id` BIGINT, `reason` VARCHAR(500); `save()`는 새 행만, `delete()`는 예외)를 만든다 in apps/moderation/models.py (ADMIN-01a, ADMIN-02, ADMIN-03)
- [ ] T024 위 모델로 앱마다 `0001_initial.py`를 만들고, 생성 열(`blogs.active_owner_id`, `categories.parent_key`)과 CHECK 제약이 마이그레이션 SQL에 그대로 들어갔는지 `sqlmigrate`로 확인한다. 손으로 DB를 고치지 않는다 in apps/*/migrations/0001_initial.py (원칙 IV)
- [ ] T025 주제 10개(일상 `daily`, 여행·맛집 `travel-food`, IT·개발 `it-dev`, 문화·연예 `culture`, 책·영화 `books-movies`, 반려동물 `pets`, 요리 `cooking`, 스포츠 `sports`, 경제·재테크 `finance`, 기타 `etc`)를 순서대로 넣는 데이터 마이그레이션을 만든다 in apps/posts/migrations/0002_seed_topics.py (POST-11)

### 공개 범위와 권한 (테스트 먼저)

- [ ] T026 [P] `visible_posts(viewer)`와 `get_post_for_viewer_or_404(blog_address, post_no, viewer)` 테스트를 쓴다. 볼 수 없는 글(비공개, 임시저장, 관리자 숨김, 주인이 이용 제한 중, 블로그 삭제, 주인 탈퇴) × 비회원·회원·주인·서비스 관리자. 주인은 자기 글을 모두 보고, 서비스 관리자도 블로그 화면에서는 남의 비공개 글이 404다. 판단 순서는 존재 → 블로그 소속 → 블로그 이용 제한 → 관리자 숨김 → 주인 여부 → 공개 범위·상태 in tests/unit/test_visibility.py (POST-04a, POST-06a, SC-003)
- [ ] T027 [P] `apps/` 소스(단, `apps/posts/visibility.py`와 마이그레이션은 빼고)에 `visibility=`, `visibility__`, `hidden_at__isnull`, `status=` 같은 공개 범위 조건이 직접 나오면 실패하는 검사 테스트를 쓴다 in tests/unit/test_visibility_single_source.py (POST-06a, 원칙 II)
- [ ] T028 [P] COM-01 권한표를 데이터로 옮긴다. 행마다 행동, 주소·메서드, 비회원·회원·블로그 주인·서비스 관리자의 기대 결과(`302 로그인`, `403`, `404`, 허용)를 적는다. P1 주소를 모두 넣고 P2 주소는 그 이야기에서 더한다 in tests/permissions/matrix.py (COM-01, SC-004)
- [ ] T029 [P] `matrix.py`의 모든 ✕ 칸을 네 상태로 주소 직접 요청(GET·POST·PUT·PATCH·DELETE)으로 시도하는 매개변수 테스트를 쓴다. 이야기가 끝날 때마다 그 행이 통과로 바뀐다 in tests/permissions/test_matrix.py (COM-01, COM-02, SC-004)
- [ ] T030 [P] 403·404·500 화면 테스트를 쓴다. 홈·이전 화면 링크가 있고, `prod` 설정에서 일부러 낸 오류에 스택·SQL·경로가 없고 "잠시 후 다시 시도해 주세요"만 보인다 in tests/integration/test_error_pages.py (COM-02, COM-02a, US6-4)
- [ ] T031 [P] CSP 헤더(`default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'`)가 모든 응답에 붙고, 템플릿에 인라인 `<script>`가 없고, `|safe`가 `templates/posts/post_detail.html`의 본문 한 곳에만 있는지 확인하는 테스트를 쓴다 in tests/unit/test_security_defaults.py (COM-P05, SC-010)
- [ ] T032 `apps/posts/visibility.py`를 만든다. `visible_posts(viewer)`(data-model 4절 '볼 수 있는 글' 1~4 조건, 이용 제한은 `user_sanctions`에서 계산), `owner_posts(blog)`, `get_post_for_viewer_or_404(blog_address, post_no, viewer)`, `get_blog_for_viewer_or_404(address, viewer)`(삭제·주인 제한이면 주인 말고는 404). 화면 코드는 이 모듈만 부른다 in apps/posts/visibility.py (POST-04a, POST-06a, ADMIN-02)
- [ ] T033 [P] `apps/core/decorators.py`에 `login_required`(비회원은 `302 → /accounts/login/?next=`, `next`는 같은 사이트 주소만), `blog_owner_required`(요청한 회원의 살아 있는 블로그를 `request.blog`로), `service_admin_required`(`role != ADMIN`이면 403)를 만든다. JSON API용은 401 + `login_url`로 답한다 in apps/core/decorators.py (COM-01, COM-02, AUTH-01h)
- [ ] T034 [P] CSP 헤더를 붙이는 작은 미들웨어를 만든다 in apps/core/middleware.py (COM-P05)
- [ ] T035 [P] 페이지 번호(`?page=N`, 10개, 숫자가 아니면 1페이지, 마지막을 넘으면 빈 목록 200)와 커서(`(published_at, id)`를 담은 불투명 문자열, 망가지면 `invalid_cursor`) 도우미를 만든다. 정렬은 언제나 `published_at DESC, id DESC` in apps/core/pagination.py (COM-P01, HOME-01a)
- [ ] T036 [P] 일회용 `client_token`(UUID)을 만들고, 같은 토큰의 행이 있으면 그것을 돌려주는 도우미를 만든다 in apps/core/client_token.py (COM-P06)
- [ ] T037 [P] JSON 오류 형식 `{"error": {"code", "message", "field"}}`을 만드는 도우미와 상태 코드 상수를 만든다 in apps/core/api.py (COM-02a)

### 공통 화면

- [ ] T038 `templates/base.html`을 만든다. 헤더(로고, 통합 검색 자리, 로그인·닉네임·로그아웃 POST 폼), 푸터(`/terms`, `/privacy` 링크), CSRF 토큰 meta, `static/js/api.js` 모듈. 시각은 한국 시간으로 보여 준다 in templates/base.html (AUTH-01e, AUTH-02, COM-P07)
- [ ] T039 [P] `templates/errors/403.html`, `templates/errors/404.html`, `templates/errors/500.html`(홈·이전 화면 링크, 내부 정보 없음)과 `config/urls.py`의 `handler403`·`handler404`·`handler500`을 만든다 in templates/errors/500.html (COM-02, COM-02a)
- [ ] T040 [P] `static/js/api.js`를 만든다. `fetch` 감싸기, `X-CSRFToken` 헤더, 401이면 `login_url`로 이동, 오류 형식의 `field` 칸 옆에 `message` 표시, 처리 중 표시 in static/js/api.js (COM-02, COM-02a, COM-P05)
- [ ] T041 [P] `static/js/form-guard.js`를 만든다. 입력 2초 뒤마다 `localStorage`에 백업하고, 다시 열면 되살리고, 성공하면 지운다(접근 실패는 조용히 넘긴다) in static/js/form-guard.js (COM-P06)
- [ ] T042 [P] 360px부터 시작하는 모바일 우선 `static/css/base.css`를 만든다. 가로 스크롤 없음, 넓은 화면은 미디어 쿼리 in static/css/base.css (COM-P07, SC-008)
- [ ] T043 `config/urls.py`에 서비스 경로를 먼저, `/{blog}/` 경로를 맨 끝에 두는 순서를 정하고 `/django-admin/`을 Django 관리 도구 자리로 둔다 in config/urls.py (BLOG-01c, ADMIN-01)

**Checkpoint**: `uv run python manage.py migrate`로 P1·P2 테이블과 주제 10개가 생기고, 스키마·주제 테스트가 통과한다. 공개 범위·권한표 테스트는 아직 화면이 없어 실패한다(정상)

---

## Phase 3: User Story 1 - 가입·로그인과 블로그 개설 (Priority: P1) 🎯 MVP

**Goal**: 이메일 또는 소셜(카카오·구글·네이버)로 가입·로그인하고, 블로그 주소와 이름을 정해 블로그를 하나 연다

**Independent Test**: 새 이메일로 가입·인증 후 로그인 → 블로그 개설 → 블로그 메인이 빈 상태로 열리는지 확인한다. 같은 흐름을 새 소셜 계정으로도 확인한다

### Tests for User Story 1 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다**

- [ ] T044 [P] [US1] 이메일 가입 테스트를 쓴다. 인증 메일을 마쳐야 로그인됨, 이미 가입된 이메일 거절, 비밀번호 7자·129자 거절, 닉네임 1자·21자·대소문자만 다른 중복 거절(앞뒤 공백은 뺀다), 필수 동의 2개와 만 14세 이상 확인 중 하나라도 빠지면 거절, 틀린 칸마다 이유가 나오고 입력이 남는다 in tests/integration/test_signup_email.py (AUTH-01a, AUTH-01e, AUTH-01f, COM-02a, US1-3)
- [ ] T045 [P] [US1] 이메일 로그인 테스트를 쓴다. 이메일이 틀려도 비밀번호가 틀려도 같은 문구 하나, 같은 이메일 5분 안 5회 실패면 막고 알림, 성공하면 `next`(같은 사이트만)로, 없으면 홈으로. 응답·주소·로그에 비밀번호가 없다 in tests/integration/test_login.py (AUTH-01b, AUTH-01g, AUTH-01h, US1-4)
- [ ] T046 [P] [US1] 비밀번호 재설정 테스트를 쓴다. 가입 여부와 관계없이 같은 안내, 메일 링크로 새 비밀번호 설정 후 로그인, 같은 링크 재사용 불가, 1시간 뒤 만료 in tests/integration/test_password_reset.py (AUTH-01c, US1-5)
- [ ] T047 [P] [US1] 소셜 가입 테스트를 쓴다(제공사 응답을 가짜로). 첫 로그인 → 동의·닉네임 한 화면(제공사 닉네임이 미리 채워짐) → 일반 회원 가입 후 원래 화면, 이메일을 주지 않아도 가입, 취소·실패하면 아무것도 바뀌지 않고 이유 안내, 같은 이메일이 다른 방식으로 이미 있으면 소셜→이메일·이메일→소셜 두 방향 모두 새 계정 없이 가입된 방식으로 안내 in tests/integration/test_social_signup.py (AUTH-01, AUTH-01d, AUTH-01e, AUTH-01h, US1-1, US1-2)
- [ ] T048 [P] [US1] 블로그 주소 검사 단위 테스트를 쓴다. `abc`(길이), `-abcd`·`abcd-`(하이픈), `ABCD`·`ab_cd`(형식), `admin`(예약어), 이미 있는 주소·삭제된 블로그 주소(영구 예약) → 각각의 이유 코드 `length`·`hyphen_edge`·`format`·`reserved`·`taken` in tests/unit/test_blog_address.py (BLOG-01a, BLOG-01b, US1-7)
- [ ] T049 [P] [US1] `config/urls.py`의 서비스 경로 첫 단어가 모두 `apps/blogs/reserved.py`에 있는지 확인하는 테스트를 쓴다 in tests/unit/test_reserved_words.py (BLOG-01a, BLOG-01c)
- [ ] T050 [P] [US1] 블로그 개설 테스트를 쓴다. 블로그 없는 회원이 글쓰기(`/manage/write`)를 누르면 `/blog/new`로, 개설 화면에 "주소는 개설 후 바꿀 수 없다" 안내, 규칙 위반 주소는 개설 전에 이유, 이름 0자·41자 거절, 성공하면 `/manage/write`로 가고 `/{blog}`가 빈 상태, 이미 블로그가 있으면 `/blog/new`가 막힘(연달아 보내도 블로그 하나), `GET /api/blogs/address-check`가 이유 코드를 준다 in tests/integration/test_blog_create.py (AUTH-04, BLOG-01, BLOG-01a, BLOG-01b, BLOG-01d, BLOG-03, US1-6, US1-7, US1-8, US1-9)
- [ ] T051 [P] [US1] 로그아웃 테스트를 쓴다. `POST /accounts/logout/` 뒤 비회원이 되고 홈으로 가며, `/manage/write`·`/manage/settings`는 로그인 화면으로 보낸다. `GET`으로는 로그아웃되지 않는다 in tests/integration/test_logout.py (AUTH-02, US1-10)
- [ ] T052 [P] [US1] `/terms`, `/privacy`가 비회원에게 열리고 모든 화면 푸터에 링크가 있는지 테스트를 쓴다 in tests/integration/test_terms_pages.py (AUTH-01e)

### Implementation for User Story 1

- [ ] T053 [US1] allauth 설정을 더한다. `ACCOUNT_EMAIL_VERIFICATION="mandatory"`, `ACCOUNT_UNIQUE_EMAIL=True`, 인증 링크 3일, `ACCOUNT_RATE_LIMITS["login_failed"]`(같은 이메일 5분 5회, 같은 IP 1분 20회), `AUTH_PASSWORD_VALIDATORS`(최소 8자, 최대 128자, 흔한 비밀번호·이메일 유사 거절), 재설정 링크 1시간, `SOCIALACCOUNT_AUTO_SIGNUP=False`, `SOCIALACCOUNT_EMAIL_AUTHENTICATION=False`, `SOCIALACCOUNT_EMAIL_AUTHENTICATION_AUTO_CONNECT=False`, 제공사 kakao·google·naver(키는 환경 변수) in config/settings/base.py (AUTH-01, AUTH-01a, AUTH-01c, AUTH-01g)
- [ ] T054 [P] [US1] 가입 폼을 만든다. 동의 칸 3개(이용약관, 개인정보 수집·이용, 만 14세 이상 확인) 공통 믹스인, 이메일 가입 폼(이메일·비밀번호·닉네임), 소셜 가입 폼(닉네임을 제공사 닉네임으로 미리 채움), 닉네임 검사(앞뒤 공백 빼고 2~20자, 대소문자 무시 중복 불가) in apps/accounts/forms.py (AUTH-01, AUTH-01e, AUTH-01f, AUTH-01i)
- [ ] T055 [US1] allauth 어댑터를 만든다. 가입 때 `terms_agreed_at`·`privacy_agreed_at` 저장, `role="MEMBER"` 고정(폼으로 바꿀 수 없음), `pre_social_login`에서 같은 이메일의 다른 방식 가입을 막고 "이 이메일은 ○○(으)로 가입돼 있습니다" 안내, 이메일 가입에서 소셜 회원 이메일이면 같은 안내, 이메일이 없으면 검사 생략, `next`는 같은 사이트만, 취소·실패면 로그인 화면에 이유 in apps/accounts/adapters.py (AUTH-01, AUTH-01d, AUTH-01h, ADMIN-01)
- [ ] T056 [US1] allauth 주소 중 pages.md 표에 있는 것만 연결하고(이메일 추가·변경, 소셜 계정 연결 관리는 뺌) `config/urls.py`에 붙인다 in apps/accounts/urls.py (AUTH-01, AUTH-01d)
- [ ] T057 [P] [US1] 로그인·가입·인증·재설정 화면 템플릿을 한국어로 만든다. 로그인 실패 문구는 "이메일 또는 비밀번호가 맞지 않습니다" 하나, 연속 실패 안내, 미인증 이메일 다시 보내기, 카카오·구글·네이버 버튼(`POST`) in templates/account/login.html (AUTH-01, AUTH-01a, AUTH-01b, AUTH-01c, AUTH-01g)
- [ ] T058 [P] [US1] 소셜 가입 한 화면(동의 3칸 + 닉네임) 템플릿을 만든다 in templates/socialaccount/signup.html (AUTH-01, AUTH-01e)
- [ ] T059 [P] [US1] `/terms`, `/privacy` 화면(문안은 자리만)과 주소를 만든다 in apps/core/views.py (AUTH-01e)
- [ ] T060 [P] [US1] pages.md 끝의 예약어 목록(`about accounts admin api blog django-admin feed help login logout manage me media notice notices privacy ranking search signup static terms topic www`)을 상수로 만든다 in apps/blogs/reserved.py (BLOG-01a)
- [ ] T061 [P] [US1] 블로그 주소 검사 함수(`[a-z0-9-]{4,32}`, 하이픈 시작·끝 불가, 예약어, 이미 쓴 주소)를 이유 코드와 함께 만든다 in apps/blogs/validators.py (BLOG-01a, BLOG-01b)
- [ ] T062 [US1] 블로그 개설 폼(주소, 이름 1~40자, 소개 0~200자 선택)과 개설 서비스를 만든다. 생성 열 `active_owner_id` 유일 키 충돌은 "이미 블로그가 있다"로 바꾼다 in apps/blogs/forms.py (BLOG-01, BLOG-01d, COM-P06)
- [ ] T063 [US1] `GET, POST /blog/new` 뷰를 만든다. 이미 블로그가 있으면 `/{blog}`로 보내고 막기, 성공 `302 → /manage/write`. `GET /api/blogs/address-check`도 같은 검사 함수로 만든다 in apps/blogs/views.py (BLOG-01, BLOG-01a, BLOG-01b)
- [ ] T064 [US1] `blog_owner_required`에 "블로그가 없으면 `/blog/new`로 302"를 더한다 in apps/core/decorators.py (AUTH-04, US1-6)
- [ ] T065 [P] [US1] 개설 화면 템플릿(주소 변경 불가 안내, 칸마다 이유)과 주소를 입력할 때 확인 API를 부르는 스크립트를 만든다 in templates/blogs/blog_new.html (BLOG-01a, BLOG-01b, COM-02a)
- [ ] T066 [P] [US1] 주소 입력 확인 스크립트를 만든다(인라인 금지, `api.js` 사용) in static/js/blog-new.js (BLOG-01a)
- [ ] T067 [US1] 블로그 메인 최소판을 만든다. `get_blog_for_viewer_or_404`로 블로그를 찾고 글이 없으면 빈 상태를 알린다(목록은 US3) in apps/blogs/views.py (BLOG-01c, BLOG-03)
- [ ] T068 [US1] 권한표 `matrix.py`에 `/blog/new`, `/api/blogs/address-check`, `/accounts/logout/` 행이 통과하는지 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: 이메일·소셜로 가입하고 블로그를 열 수 있다. US1 테스트가 모두 통과한다

---

## Phase 4: User Story 2 - 글 쓰고 발행·수정·삭제하기 (Priority: P1)

**Goal**: 블로그 주인이 Quill 에디터로 이미지·서식이 든 글을 쓰고, 카테고리·태그·공개 범위를 정해 발행·수정·삭제한다

**Independent Test**: 블로그 주인으로 이미지·서식이 들어간 글을 발행 → 상세 화면 확인 → 수정 → 삭제까지 진행한다

### Tests for User Story 2 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 중복 처리(US2-5)와 비공개 404(US2-8)는 특히 먼저다**

- [ ] T069 [P] [US2] 본문 정제 단위 테스트를 쓴다. 허용 태그 `p h2 h3 strong em u s span a ol ul li blockquote pre code img br`만 남음, `<script>` `<style>` `<iframe>`은 내용째 삭제, `onerror` 같은 이벤트 속성·`javascript:` 링크 삭제, `a`에 `target="_blank" rel="noopener noreferrer nofollow"` 강제, `img[src]`는 `/media/...`만, `class`는 `ql-align-*`·`ql-syntax`만, `style`은 `color`만. `content_text`, 앞 150자 `excerpt`, 첫 이미지, 빈 본문 판단(공백·빈 줄만 = 빈 본문, 이미지만 = 발행 가능) in tests/unit/test_sanitize.py (POST-01a, POST-01b, COM-P01, COM-P05, SC-010, US2-9)
- [ ] T070 [P] [US2] 발행 규칙 단위 테스트를 쓴다. 제목 앞뒤 공백 뺀 1~100자, 제목 → 본문 순서로 첫 문제, 태그 이름 정리(앞뒤 공백·맨 앞 `#` 제거, 1~20자, 글당 10개, 대소문자만 다르면 같은 태그), data-model 4절 '발행일 규칙' 표 6행(공개 발행, 비공개 발행, 비공개 → 처음 공개, 공개 뒤 변경, 수정) in tests/unit/test_post_rules.py (POST-01a, POST-06, TAG-01, COM-P02)
- [ ] T071 [P] [US2] 발행 통합 테스트를 쓴다. 새 글 화면이 빈 상태, 제목 공백이면 제목 오류·본문 비면 본문 오류(입력 유지), 제목·본문·이미지·태그 발행 → `302 → /{blog}/{no}`이고 공감·댓글·조회 0, 카테고리를 안 고르면 미분류, 같은 `client_token` 연속 요청은 글 하나, 다른 블로그의 카테고리·태그 id는 거절 in tests/integration/test_post_publish.py (POST-01, POST-01a, POST-01c, COM-P06, COM-02a, US2-1, US2-2, US2-3, US2-4, US2-5)
- [ ] T072 [P] [US2] 동시 발행 테스트를 쓴다(`transaction=True`). 같은 블로그에 두 글을 동시에 발행해도 `post_no`가 겹치지 않고, 지운 번호는 다시 쓰지 않는다 in tests/integration/test_post_number_concurrency.py (POST-01d, SC-005)
- [ ] T073 [P] [US2] 수정·삭제 테스트를 쓴다. 수정해도 `post_no`·`published_at`·공감·댓글·조회수·목록 순서가 그대로이고 발행 때와 같은 검사를 거침, 남의 글·없는 번호 수정은 404, 삭제는 `POST`만이고 한 트랜잭션으로 댓글·공감·태그 연결·이미지 연결·조회 기록·순위 항목을 함께 지우고 `last_post_no`는 그대로, 삭제 후 그 주소는 404, 공개 범위를 바꿀 수 있음 in tests/integration/test_post_edit_delete.py (POST-02, POST-03, POST-06, COM-P04, US2-6, US2-7)
- [ ] T074 [P] [US2] 글 상세 테스트를 쓴다. 제목·발행일·카테고리·본문·태그·공감 수·댓글이 보이고 주인에게만 수정·삭제, 비공개 글은 다른 사람(관리자 포함)에게 404, 다른 블로그 주소에 남의 글 번호를 붙이면 404, 한글 태그 주소가 열림 in tests/integration/test_post_detail.py (POST-04, POST-04a, POST-06, US2-8)
- [ ] T075 [P] [US2] 이미지 업로드 테스트를 쓴다. jpg·png·gif·webp 허용(`201`, 가로 480px 작은 이미지), 확장자만 바꾼 파일 `400 invalid_image`, 10MB 초과 `413 image_too_large`, JPEG EXIF 방향 보정, 움직이는 GIF 원본 유지, 파일 이름은 UUID, 비회원 401, 남의 이미지는 글에 연결되지 않음 in tests/integration/test_image_upload.py (POST-05, COM-P03)
- [ ] T076 [P] [US2] Playwright 테스트를 쓴다. 굵게·기울임·글자색·정렬·목록·인용·코드 블록·링크 서식이 저장 후 다시 열어도 남음, 동영상 버튼 없음, 이미지 여러 장이 고른 순서대로 커서 위치에 들어감, 외부 링크가 새 창, 발행을 세 번 연달아 눌러도 글 하나, 삭제 전 확인 창 in tests/e2e/test_us2_editor.py (POST-01b, POST-05, COM-P04, US2-5)

### Implementation for User Story 2

- [ ] T077 [P] [US2] nh3 허용 목록 정제 함수를 만든다. 정제한 HTML, `content_text`, `excerpt`(150자), 첫 이미지 id, 빈 본문 여부를 함께 돌려준다 in apps/posts/sanitize.py (POST-01a, POST-01b, COM-P01, COM-P05)
- [ ] T078 [P] [US2] Pillow 이미지 검사·저장 함수를 만든다. 내용으로 jpg·png·gif·webp 판단, 10MB 상한, JPEG EXIF 방향 반영, GIF·PNG·WEBP 원본 저장, 가로 480px 작은 이미지(움직이는 GIF는 첫 장면), UUID 이름. 회원·블로그 프로필도 이 함수를 쓴다 in apps/posts/images.py (POST-05, COM-P03)
- [ ] T079 [P] [US2] 태그 이름 정리 함수(앞뒤 공백·맨 앞 `#` 제거, 1~20자)와 글당 10개 검사를 만든다 in apps/posts/tags.py (TAG-01)
- [ ] T080 [US2] `POST /api/images`를 만든다(회원, `multipart/form-data` 칸 `file`, api.md 응답·오류 코드) in apps/posts/api.py (POST-05, COM-P03)
- [ ] T081 [US2] 글 폼을 만든다. 제목 → 본문 순서 검사, 카테고리(자기 블로그 것만), 태그, 공개 범위(기본 `PUBLIC`), 숨은 `client_token` in apps/posts/forms.py (POST-01, POST-01a, POST-06)
- [ ] T082 [US2] 글 서비스를 만든다. `publish_post`: 한 트랜잭션에서 `SELECT ... FOR UPDATE`로 블로그 행 잠금 → `last_post_no + 1` → 저장(`(blog_id, client_token)` 충돌이면 처음 글 반환) → 태그 정리·연결 → `post_images` 재구성(`uploader_id` 검사). 발행일은 '발행일 규칙' 표대로. `update_post`(번호·발행일 유지), `delete_post`(한 트랜잭션), `change_visibility`(처음 공개면 `published_at` 다시 정함) in apps/posts/services.py (POST-01, POST-01d, POST-02, POST-03, POST-06, COM-P02, COM-P06)
- [ ] T083 [US2] 뷰를 만든다. `GET, POST /manage/write`(빈 에디터, 실패하면 첫 오류 + 입력 유지), `GET, POST /manage/write/{no}`(자기 블로그에 없으면 404), `POST /manage/posts/{no}/delete`(성공 `302 → /{blog}`), `GET /{blog}/{no}`(`get_post_for_viewer_or_404`). 상태를 바꾸는 뷰는 `require_POST` in apps/posts/views.py (POST-01, POST-01c, POST-02, POST-03, POST-04, POST-04a)
- [ ] T084 [US2] 글쓰기·상세 주소를 연결한다(`/manage/write`, `/manage/write/<no>`, `/manage/posts/<no>/delete`, `/<blog>/<no>`) in apps/posts/urls.py (BLOG-01c)
- [ ] T085 [P] [US2] 글쓰기 화면 템플릿을 만든다(제목, 에디터 자리, 숨은 본문 칸, 카테고리·태그·공개 범위, 칸별 오류) in templates/posts/write.html (POST-01, COM-02a)
- [ ] T086 [P] [US2] 글 상세 템플릿을 만든다. 본문만 `|safe`, 나머지는 자동 이스케이프, 주인에게 수정·삭제(삭제는 확인 창 + POST 폼), 원본 이미지는 여기서만 in templates/posts/post_detail.html (POST-04, COM-P03, COM-P04, COM-P05)
- [ ] T087 [US2] Quill 에디터 스크립트를 만든다. 툴바(문단 제목, 굵게, 기울임, 글자색, 정렬, 목록, 인용, 코드 블록, 링크, 이미지; 동영상 없음), 이미지 버튼을 가로채 고른 순서대로 하나씩 `/api/images`에 올려 커서 위치에 넣기, 실패하면 본문을 건드리지 않고 이유 표시, 제출 때 숨은 칸에 HTML 넣기, `form-guard.js` 백업, 발행 중 버튼 잠금 in static/js/editor.js (POST-01b, POST-05, COM-P03, COM-P06)
- [ ] T088 [P] [US2] 에디터·본문 스타일을 만든다(360px에서 툴바 줄바꿈) in static/css/editor.css (POST-01b, COM-P07)
- [ ] T089 [US2] 권한표 `matrix.py`에 글쓰기·수정·삭제·이미지 업로드 행을 채우고 통과를 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: 블로그 주인이 글을 발행·수정·삭제할 수 있고, 비공개 글과 스크립트가 새지 않는다

---

## Phase 5: User Story 3 - 한 블로그 둘러보기 (Priority: P1)

**Goal**: 블로그 메인 목록, 사이드바 카테고리·글 수, 카테고리·태그 목록, 블로그 안 검색, 블로그 설정

**Independent Test**: 글이 10개 넘는 블로그에서 메인 페이지 넘기기, 카테고리·태그 목록, 블로그 내 검색을 차례로 확인한다

### Tests for User Story 3 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 비공개 글이 목록·개수에서 빠지는지(US3-3)는 특히 먼저다**

- [ ] T090 [P] [US3] 블로그 메인 테스트를 쓴다. 발행일 최신순(같으면 나중에 만든 글이 위), 글마다 제목·발행일·카테고리·요약, 10개씩, 마지막을 넘는 페이지는 빈 목록 200, `page`가 숫자가 아니면 1페이지, 글이 없으면 빈 상태, 없는 블로그 주소는 404 in tests/integration/test_blog_main.py (BLOG-03, COM-P01, US3-1, US3-6, US3-7)
- [ ] T091 [P] [US3] 사이드바 테스트를 쓴다. 블로그 메인·글·카테고리·태그·검색 화면에 같은 사이드바(이름·프로필 → 메인), '전체 글' 맨 위·'미분류' 맨 아래, 미분류 글이 없으면 미분류 숨김, 주인이 아닌 사람에게 비공개 글이 목록과 개수에서 모두 빠짐 in tests/integration/test_sidebar.py (BLOG-04, POST-06a, US3-2, US3-3)
- [ ] T092 [P] [US3] 카테고리 테스트를 쓴다. 추가·이름 변경·삭제, 이름 앞뒤 공백 뺀 1~20자, 같은 단계 이름 중복 거절, 블로그당 100개, 삭제하면 한 트랜잭션으로 글이 미분류로, 이름을 바꿔도 `/{blog}/category/{id}` 그대로, 다른 블로그 카테고리 번호는 404, `/{blog}/uncategorized`, 새 블로그는 카테고리 없이 시작 in tests/integration/test_categories.py (CAT-01, CAT-02)
- [ ] T093 [P] [US3] 태그 목록 테스트를 쓴다. `/{blog}/tag/{name}`이 같은 블로그의 그 태그 글만, 한글 태그 퍼센트 인코딩 주소가 열림, `Travel`과 `travel`은 같은 목록, 없는 태그는 404 in tests/integration/test_tag_posts.py (TAG-01, TAG-02)
- [ ] T094 [P] [US3] 블로그 안 검색 테스트를 쓴다. 제목·본문(서식 제외)·태그 부분 일치, 앞뒤 공백이 붙은 대소문자 바꾼 영문이 같은 결과, 공백뿐이면 검색하지 않음, `%`·`_` 이스케이프, 100자로 자름, 결과가 없으면 안내 + 검색어 유지, 주소로 같은 결과(새로고침·공유), 볼 수 없는 글 제외 in tests/integration/test_blog_search.py (SRCH-01, POST-06a, US3-4, US3-5)
- [ ] T095 [P] [US3] 블로그 설정 테스트를 쓴다. 이름·소개·블로그 프로필 이미지 변경, 이미지가 없으면 기본 이미지, 소개가 비면 소개 자리 숨김, 소개 201자 거절, 주소는 보여 주기만 하고 바꿀 수 없음, 프로필을 바꾸면 이전 파일 삭제 in tests/integration/test_blog_settings.py (BLOG-02, BLOG-01b)
- [ ] T096 [P] [US3] 쿼리 수 테스트를 쓴다. 블로그 메인·카테고리·태그·검색 목록에서 글 10개와 20개일 때 쿼리 수가 같다(`django_assert_max_num_queries`) in tests/integration/test_blog_query_counts.py (COM-P01, SC-007)

### Implementation for User Story 3

- [ ] T097 [P] [US3] 사이드바 데이터를 만든다. 카테고리 목록(이 단계에서는 이름순, 순서는 US8)과 `visible_posts(viewer)` 기준 카테고리별·미분류·전체 글 수를 `annotate` 한 번으로 in apps/blogs/sidebar.py (BLOG-04, POST-06a)
- [ ] T098 [P] [US3] 블로그 안 검색 함수를 만든다. 검색어 정리(앞뒤 공백, 1~100자), `LIKE` 이스케이프, 제목·`content_text`·태그 이름 부분 일치, `visible_posts`에서 시작 in apps/posts/search.py (SRCH-01)
- [ ] T099 [P] [US3] 카테고리 서비스를 만든다. 추가·이름 변경·삭제(한 트랜잭션: 글을 `category_id = NULL`로 옮긴 뒤 삭제), 100개 상한, 같은 단계 이름 검사 in apps/posts/categories.py (CAT-01)
- [ ] T100 [US3] 블로그 메인 목록을 완성한다(`visible_posts` + 페이지 번호, `select_related`로 카테고리) in apps/blogs/views.py (BLOG-03, COM-P01)
- [ ] T101 [US3] 목록 뷰를 만든다. `GET /{blog}/category/{id}`, `GET /{blog}/uncategorized`, `GET /{blog}/tag/{name}`, `GET /{blog}/search?q=&page=`. 모두 `visible_posts`와 페이지 도우미를 쓴다 in apps/posts/views.py (CAT-02, TAG-02, SRCH-01, COM-P01)
- [ ] T102 [US3] 카테고리 관리 뷰를 만든다(`GET, POST /manage/categories`, `POST /manage/categories/{id}`, `POST /manage/categories/{id}/delete`, 확인 후 삭제) in apps/posts/views.py (CAT-01, COM-P04)
- [ ] T103 [US3] 블로그 설정 폼·뷰를 만든다(`GET, POST /manage/settings`, 이름 1~40자, 소개 0~200자, 프로필 이미지는 `apps/posts/images.py` 검사, 바꾸면 이전 파일 삭제) in apps/blogs/views.py (BLOG-02, BLOG-01d)
- [ ] T104 [P] [US3] 블로그 공통 레이아웃을 만든다. 사이드바(좁은 화면은 본문 아래 `<details>`), 프로필 기본 이미지, 소개가 비면 숨김 in templates/blog_base.html (BLOG-04, BLOG-02, COM-P07)
- [ ] T105 [P] [US3] 글 목록 조각 템플릿(제목·발행일·카테고리·요약·작은 대표 이미지, 빈 상태, 페이지 링크)을 만든다 in templates/posts/_post_list.html (BLOG-03, COM-P01, COM-P03)
- [ ] T106 [P] [US3] 블로그 메인·카테고리·태그·검색 결과 템플릿을 만든다(검색은 결과가 없으면 검색어를 남긴 채 안내) in templates/posts/search.html (BLOG-03, CAT-02, TAG-02, SRCH-01)
- [ ] T107 [P] [US3] 카테고리 관리 템플릿(`templates/posts/manage_categories.html`)과 블로그 설정 템플릿을 만든다 in templates/blogs/manage_settings.html (CAT-01, BLOG-02)
- [ ] T108 [P] [US3] 블로그 화면 스타일을 만든다(360px 한 줄, 넓은 화면 사이드바 옆) in static/css/blog.css (COM-P07, SC-008)
- [ ] T109 [P] [US3] 시연용 글을 만드는 관리 명령 `seed_demo --posts N --blog ADDRESS`를 만든다(quickstart 이야기 3) in apps/posts/management/commands/seed_demo.py (COM-P01, US3-1)
- [ ] T110 [US3] 권한표 `matrix.py`에 카테고리 관리·블로그 설정 행을 채우고 통과를 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: 한 블로그 안에서 목록·카테고리·태그·검색이 모두 동작하고, 볼 수 없는 글은 개수에서도 빠진다

---

## Phase 6: User Story 4 - 홈에서 새 글 발견하기 (Priority: P1)

**Goal**: 비회원도 홈에서 여러 블로그의 최신 공개 글을 랜딩 없이 보고, 더 불러오기로 이어 본다

**Independent Test**: 서로 다른 블로그 두 곳에 공개 글·비공개 글을 발행하고, 비회원으로 홈을 열어 공개 글만 최신순으로 보이는지 확인한다

### Tests for User Story 4 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다**

- [ ] T111 [P] [US4] 홈 테스트를 쓴다. `GET /`가 랜딩 없이 최신 글 첫 20개, 글마다 제목·블로그 이름·발행일·요약, 비공개·관리자 숨김·주인 이용 제한·삭제 블로그 글 제외, 비공개 → 공개로 바꾼 글은 바꾼 시각으로 맨 위, 쿼리 수가 글 수와 무관 in tests/integration/test_home.py (HOME-01, HOME-01a, POST-06a, COM-P02, US4-1, US4-2)
- [ ] T112 [P] [US4] 홈 더 불러오기 테스트를 쓴다. `GET /api/home/latest?cursor=`를 끝까지 반복해도 중복·누락 없음(중간에 새 글이 생겨도), 망가진 커서 `400 invalid_cursor`, JS 없을 때 같은 커서의 "다음" 링크 in tests/integration/test_home_cursor.py (HOME-01a, US4-3)
- [ ] T113 [P] [US4] Playwright 테스트를 쓴다. 더 불러오기를 끝까지 눌러 같은 글이 두 번 나오지 않음, JS를 끈 채 "다음" 링크로 같은 결과 in tests/e2e/test_us4_home.py (HOME-01a, US4-3)

### Implementation for User Story 4

- [ ] T114 [US4] 홈 뷰와 `GET /api/home/latest`를 만든다(`visible_posts(viewer)` + 커서, 20개, `select_related("blog")`) in apps/discovery/views.py (HOME-01, HOME-01a)
- [ ] T115 [US4] 홈 주소 `/`와 API 주소를 연결한다 in apps/discovery/urls.py (HOME-01)
- [ ] T116 [P] [US4] 홈 템플릿을 만든다(최신 글 목록, JS 없을 때 "다음" 링크) in templates/discovery/home.html (HOME-01, HOME-01a)
- [ ] T117 [P] [US4] 더 불러오기 스크립트를 만든다(`next_cursor`로 이어 붙이고 `textContent`로만 넣음, 더 없으면 버튼 숨김) in static/js/load-more.js (HOME-01a, COM-P05)

**Checkpoint**: 비회원이 홈에서 여러 블로그의 공개 글만 최신순으로 본다

---

## Phase 7: User Story 5 - 댓글과 공감으로 소통하기 (Priority: P1)

**Goal**: 회원이 남의 글에 댓글을 쓰고 공감을 누르며, 블로그 주인은 자기 블로그 댓글을 지운다

**Independent Test**: 회원 A가 회원 B의 글에 댓글·공감 → B가 그 댓글 삭제 → 비회원이 댓글·공감 시도 시 로그인 안내를 확인한다

### Tests for User Story 5 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 연타 중복(US5-3, US5-4)과 권한(US5-5)은 특히 먼저다**

- [ ] T118 [P] [US5] 댓글 테스트를 쓴다. 비회원이 쓰려 하면 로그인 후 원래 글로 돌아옴, 등록하면 작성순 끝에 닉네임·회원 프로필·한국 시간 날짜와 시각, 댓글 수 +1, 앞뒤 공백 뺀 1~1,000자, 10초 안 재등록 `429 too_fast`, 같은 `client_token` 연속 요청은 하나, 스크립트가 든 댓글이 이스케이프됨, 볼 수 없는 글에는 404, `GET /api/posts/{post_id}/comments?after=` 50개씩 in tests/integration/test_comments.py (CMT-01, AUTH-01i, COM-02, COM-P05, COM-P06, US5-1, US5-2, US5-3)
- [ ] T119 [P] [US5] 댓글 삭제 권한 테스트를 쓴다. 작성자는 자기 댓글 삭제, 블로그 주인은 자기 블로그 글의 모든 댓글 삭제, 다른 회원은 403, 누구도 남의 댓글 내용을 고칠 길이 없음(수정 주소 없음), 지우면 댓글 수 -1, JS 없는 폼(`POST /{blog}/{no}/comments/{id}/delete`)도 같은 결과 in tests/integration/test_comment_delete.py (CMT-02, COM-P04, US5-5)
- [ ] T120 [P] [US5] 공감 테스트를 쓴다. `PUT`·`DELETE /api/posts/{post_id}/like`를 몇 번 보내도 행은 0 또는 1이고 `like_count`가 실제 행 수, 이미 공감한 글을 다시 누르면 취소, 자기 글 `403 own_post`, 비회원 401 + `login_url`, 볼 수 없는 글 404, 동시 요청도 하나, JS 없는 `POST /{blog}/{no}/like`·`unlike` in tests/integration/test_likes.py (SOC-01, COM-P06, SC-005, US5-1, US5-4)
- [ ] T121 [P] [US5] Playwright 테스트를 쓴다. 비회원 공감 → 로그인 → 같은 글로 복귀, 공감 버튼이 바로 바뀌고 새로고침해도 수치가 같음, 등록 버튼 연타에도 댓글 하나 in tests/e2e/test_us5_comment_like.py (SOC-01, CMT-01, US5-1, US5-3, US5-4)

### Implementation for User Story 5

- [ ] T122 [P] [US5] 댓글 서비스를 만든다. `create_comment`(길이 검사, 10초 간격, `client_token` 중복이면 처음 댓글), `delete_comment`(작성자 또는 글의 블로그 주인), 댓글 수는 숨기지 않은 행을 매번 센다 in apps/comments/services.py (CMT-01, CMT-02, COM-P06)
- [ ] T123 [P] [US5] 공감 서비스를 만든다. `like`(자기 글이면 `own_post`, 유일 키 충돌은 성공으로), `unlike`, 공감 수는 행 수 in apps/social/services.py (SOC-01, COM-P06)
- [ ] T124 [US5] 댓글 API를 만든다. `GET /api/posts/{post_id}/comments?after=`, `POST /api/posts/{post_id}/comments`(`201`, 같은 토큰 `200`), `DELETE /api/comments/{id}`. 글은 `get_post_for_viewer_or_404`로 찾는다 in apps/comments/api.py (CMT-01, CMT-02, POST-04a)
- [ ] T125 [US5] JS 없는 댓글 폼 뷰를 만든다(`POST /{blog}/{no}/comments` → `#comment-{id}`, `POST /{blog}/{no}/comments/{id}/delete`) in apps/comments/views.py (CMT-01, CMT-02)
- [ ] T126 [US5] 공감 API(`PUT`·`DELETE /api/posts/{post_id}/like`)와 JS 없는 `POST /{blog}/{no}/like`·`unlike`를 만든다 in apps/social/api.py (SOC-01)
- [ ] T127 [P] [US5] 댓글 영역 조각 템플릿을 만든다(작성자 닉네임·회원 프로필, 한국 시간, 주인·작성자에게만 삭제, 비회원에게는 로그인 링크) in templates/comments/_comments.html (CMT-01, CMT-02, AUTH-01i)
- [ ] T128 [US5] 글 상세에 공감 수·댓글 수(`annotate`)와 공감 버튼·댓글 영역을 넣는다 in templates/posts/post_detail.html (POST-04, SOC-01, CMT-01)
- [ ] T129 [P] [US5] 댓글 스크립트를 만든다(`textContent`로만 넣기, 삭제 전 확인 창, 등록 중 버튼 잠금, 실패해도 입력 유지) in static/js/comments.js (CMT-01, CMT-02, COM-P04, COM-P05, COM-P06)
- [ ] T130 [P] [US5] 공감 버튼 스크립트를 만든다(원하는 상태를 `PUT`/`DELETE`로 보냄, 요청 중 잠금, 응답 수치로 갱신) in static/js/toggle.js (SOC-01, COM-P06)
- [ ] T131 [US5] 권한표 `matrix.py`에 댓글·공감 행을 채우고 통과를 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: 두 회원이 서로의 글에 댓글·공감을 남기고, 수치가 언제나 실제 값과 같다

---

## Phase 8: User Story 6 - 권한 지키기와 관리자 영역 (Priority: P1)

**Goal**: 주소를 직접 입력해도 권한표가 지켜지고, 서비스 관리자만 들어가는 관리 영역이 있다. P1 한 바퀴를 브라우저로 확인한다

**Independent Test**: 회원 A로 로그인한 채 회원 B의 글 수정 주소·관리 영역 주소를 직접 입력하고, 비회원으로 글쓰기 주소를 직접 입력해 결과를 확인한다

### Tests for User Story 6 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다**

- [ ] T132 [P] [US6] 접근 제어 테스트를 쓴다. 비회원이 `/manage/write`·`/manage/settings`에 직접 들어가면 로그인 후 그 화면으로, 다른 사이트 `next`는 무시, 일반 회원 `/admin` 403, `/manage/write/{no}`에 남의 글 번호면 404, 누구든(관리자 포함) 남의 비공개 글 주소는 403이 아니라 404, CSRF 토큰 없는 `POST`와 API 요청 403, `GET`으로 상태가 바뀌는 주소가 없음 in tests/integration/test_access_control.py (COM-01, COM-02, COM-P05, POST-04a, US6-1, US6-2, US6-3)
- [ ] T133 [P] [US6] 서비스 관리자 테스트를 쓴다. `create_service_admin <email>`로만 `role=ADMIN`이 되고 가입 폼에 `role`을 넣어도 무시, 관리자만 `/admin` 열림, 관리 영역에 남의 글·댓글 내용 수정 기능이 없음 in tests/integration/test_service_admin.py (ADMIN-01, ADMIN-01a, US6-5)
- [ ] T134 [P] [US6] `/django-admin/`에 `Post`·`Comment`·`GuestbookEntry`가 등록되지 않았고, 등록된 운영 데이터(회원·주제·순위)는 읽기 전용인지 `admin.site._registry`로 확인하는 테스트를 쓴다 in tests/unit/test_django_admin_registry.py (ADMIN-01a, 원칙 II)
- [ ] T135 [P] [US6] P1 한 바퀴 Playwright 테스트를 쓴다. 두 회원이 가입 → 개설 → 발행 → 상대 글을 홈에서 발견 → 읽기·댓글·공감 in tests/e2e/test_p1_loop.py (SC-001, SC-002)
- [ ] T136 [P] [US6] 360px 화면 테스트를 쓴다. P1 화면(홈, 가입, 개설, 글쓰기, 글 상세, 블로그 메인, 검색)에서 `document.documentElement.scrollWidth <= 360`, 사이드바는 본문 아래 접기, 시각이 한국 시간. 크로미움·웹킷 둘 다 in tests/e2e/test_mobile_360.py (COM-P07, SC-008, SC-009)

### Implementation for User Story 6

- [ ] T137 [P] [US6] 관리 명령 `create_service_admin <email>`을 만든다(있는 회원이면 `role=ADMIN`, 없으면 만들고 비밀번호 설정 링크 안내) in apps/accounts/management/commands/create_service_admin.py (ADMIN-01)
- [ ] T138 [US6] 서비스 관리 홈 `GET /admin`(`service_admin_required`, 회원·글 검색 바로가기 자리)과 주소를 만든다 in apps/moderation/views.py (ADMIN-01)
- [ ] T139 [P] [US6] 관리 홈 템플릿을 만든다 in templates/moderation/admin_home.html (ADMIN-01)
- [ ] T140 [P] [US6] `/django-admin/`에 `User`만 읽기 전용으로 등록한다(글·댓글·방명록은 등록하지 않음) in apps/accounts/admin.py (ADMIN-01a)
- [ ] T141 [P] [US6] `/django-admin/`에 `Topic`, `RankingSnapshot`을 읽기 전용으로 등록한다 in apps/discovery/admin.py (ADMIN-01a)
- [ ] T142 [US6] 권한표 `matrix.py`의 P1 행이 모두 있고 모든 ✕ 칸이 통과하는지 확인한다. 빠진 주소가 있으면 더한다 in tests/permissions/matrix.py (COM-01, SC-004)

**Checkpoint**: P1 끝. `make test`가 통과하고 quickstart 6절 이야기 1~6을 손으로 확인했다(SC-002). 여기까지가 MVP다

---

## Phase 9: User Story 7 - 인기 글·주제·통합 검색 (Priority: P2)

**Goal**: 조회수를 세고 매 정각 인기 글 순위를 만들며, 홈에 인기 글·주제별 글을, 헤더에 통합 검색을 둔다

**Independent Test**: 특정 글을 정각 직전 1시간 동안 여러 번 열고, 정각 이후 홈 인기 글 1위로 바뀌는지 확인한다. 통합 검색으로 다른 블로그의 글과 블로그 이름이 함께 찾아지는지 확인한다

### Tests for User Story 7 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 순위에서 볼 수 없는 글이 빠지는지는 특히 먼저다**

- [ ] T143 [P] [US7] 조회수 테스트를 쓴다. 같은 방문자 키가 30분 안에 다시 열면 세지 않음, 30분 뒤에는 셈, `bot`·`crawler`·`spider` User-Agent 제외, 블로그 주인 조회도 셈, 방문자 키는 SHA-256으로만 저장, 조회 기록과 `view_count` +1이 한 트랜잭션, 볼 수 없는 글은 기록하지 않음 in tests/unit/test_view_count.py (POST-09)
- [ ] T144 [P] [US7] 정각 집계 테스트를 쓴다. `HH:00` 순위 = `(HH-1):00 ≤ 조회 < HH:00`, 다음 정각까지 같은 순위, 1시간 조회가 0이면 24시간 기준(`basis=24H`), 그것도 0이면 `EMPTY`, 같은 정각에 두 번 돌아도 스냅숏 하나, 동점은 발행일이 늦은 글 위, 100위까지, 집계 대상은 비회원 기준 `visible_posts`, 항목은 `post_id`만 채움 in tests/unit/test_compute_rankings.py (HOME-02, POST-09, US7-1, US7-2)
- [ ] T145 [P] [US7] 홈 인기 글 표시 테스트를 쓴다. 가장 최근 스냅숏을 보여 주되 정각 사이에 비공개·삭제·숨김이 된 글은 바로 빠지고 아래 순위가 올라옴, 빈 상태 안내 in tests/integration/test_home_ranking.py (HOME-02, POST-06a, SC-003, SC-006, US7-2)
- [ ] T146 [P] [US7] 주제 테스트를 쓴다. 글쓰기에서 주제 10개 중 하나 또는 '주제 없음', `/topic/{slug}`가 그 주제의 공개 글 최신순, 주제 없는 글은 어느 주제에도 없음, 없는 slug 404, `GET /api/topics/{slug}/posts?cursor=` 중복·누락 없음, 홈 주제 영역 in tests/integration/test_topics.py (POST-11, HOME-03, US7-3)
- [ ] T147 [P] [US7] 통합 검색 테스트를 쓴다. `GET /search?q=`가 "글"·"블로그" 탭과 각 개수, 글마다 소속 블로그, 정확도순(제목 3·태그 2·본문 1, 같으면 최신)·최신순, 블로그는 이름·소개 부분 일치, 비공개 글과 이용 제한·삭제 블로그 제외, 공백뿐이면 검색하지 않고 안내, 결과가 없으면 인기 글 추천, 모든 화면 헤더에 검색창 in tests/integration/test_global_search.py (SRCH-02, POST-06a, US7-4)

### Implementation for User Story 7

- [ ] T148 [P] [US7] 조회 기록 함수를 만든다. 방문자 키(회원 ID / 서명된 1년 쿠키 / IP + User-Agent를 서버 비밀 값과 SHA-256), 로봇 제외, 30분 중복 검사, 한 트랜잭션에서 `post_views` 추가 + `view_count` +1 in apps/posts/viewcount.py (POST-09)
- [ ] T149 [US7] 글 상세 `GET /{blog}/{no}`에서 조회 기록을 남긴다(plan Complexity Tracking의 GET 예외) in apps/posts/views.py (POST-09)
- [ ] T150 [P] [US7] 순위 계산 함수를 만든다(구간, 24시간 대체, `EMPTY`, 동점 규칙, 100위, `(kind, window_end)` 충돌이면 건너뜀) in apps/discovery/rankings.py (HOME-02)
- [ ] T151 [US7] 관리 명령 `compute_rankings [--now]`를 만들고 `deploy/crontab`에 `0 * * * * compute_rankings`를 더한다 in apps/discovery/management/commands/compute_rankings.py (HOME-02, SC-006)
- [ ] T152 [P] [US7] 통합 검색 함수를 만든다(글: `visible_posts` + 점수, 블로그: 이름·소개 부분 일치에서 삭제·이용 제한 제외, 페이지 번호) in apps/discovery/search.py (SRCH-02)
- [ ] T153 [US7] 홈에 인기 글(최근 스냅숏을 `visible_posts`로 다시 걸러 10개)과 주제 영역(주제별 6개)을 더하고, `GET /topic/{slug}`, `GET /api/topics/{slug}/posts`, `GET /search`를 만든다 in apps/discovery/views.py (HOME-02, HOME-03, SRCH-02)
- [ ] T154 [US7] 글 폼과 글쓰기 화면에 주제 선택(10개 + '주제 없음')을 더한다 in apps/posts/forms.py (POST-11)
- [ ] T155 [P] [US7] 주제별 글·통합 검색 템플릿을 만들고 홈 템플릿에 인기 글·주제 영역을 더한다 in templates/discovery/search.html (HOME-02, HOME-03, SRCH-02)
- [ ] T156 [US7] 헤더에 통합 검색창(`GET /search`)을 넣는다 in templates/base.html (SRCH-02)

**Checkpoint**: 정각마다 인기 글이 바뀌고, 주제·통합 검색이 동작한다

---

## Phase 10: User Story 8 - 글쓰기와 읽기 편의 (Priority: P2)

**Goal**: 임시저장, 대표 이미지, 하위 카테고리·순서, 이전·다음 글, 태그 모아 보기, 글 주소 복사, 로그인 유지

**Independent Test**: 쓰던 글을 임시저장 → 새 글 쓰기를 열 때 이어 쓸지 묻는지 확인 → 발행 후 임시저장이 사라지는지 확인한다

### Tests for User Story 8 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다**

- [ ] T157 [P] [US8] 임시저장 테스트를 쓴다. `PUT /api/drafts/current`가 제목·본문이 비어도 저장하고 `post_no`를 쓰지 않음, 새 글 쓰기를 열면 이어 쓸지 물음, 발행하면 같은 행이 글이 되어 임시저장이 사라짐, 임시저장 글은 다른 사람에게 404이고 목록·개수에 없음 in tests/integration/test_drafts.py (POST-08, POST-01d, POST-06a, US8-1)
- [ ] T158 [P] [US8] 대표 이미지 테스트를 쓴다. 본문 이미지 중 하나를 고르거나 따로 올림, 고르지 않으면 본문 첫 이미지, 없으면 대표 이미지 없이 목록 표시(작은 이미지) in tests/integration/test_cover_image.py (POST-07, COM-P03, US8-2)
- [ ] T159 [P] [US8] 하위 카테고리·순서 테스트를 쓴다. 한 단계까지만, 하위가 있는 카테고리는 다른 카테고리 아래로 못 감, 상위가 다르면 같은 이름 허용, 상위를 고르면 하위 글까지·글 수 합침, 하위가 있는 상위는 삭제 불가(이유 안내), 주인이 정한 순서대로 사이드바 in tests/integration/test_subcategories.py (CAT-03, CAT-04, US8-3)
- [ ] T160 [P] [US8] 이전·다음 글 테스트를 쓴다. 같은 블로그 발행 순서, 보는 사람이 볼 수 없는 글(비공개·임시저장·숨김)은 건너뜀, 주인은 자기 글을 모두 지나감 in tests/integration/test_prev_next.py (POST-10, POST-06a, US8-4)
- [ ] T161 [P] [US8] 태그 모아 보기 테스트를 쓴다. `/{blog}/tags`가 볼 수 있는 글이 있는 태그만, 누르면 태그별 목록 in tests/integration/test_tag_cloud.py (TAG-03)
- [ ] T162 [P] [US8] 로그인 유지 테스트를 쓴다. 세션 14일, 요청할 때마다 연장, 브라우저를 닫아도 유지, 만료 뒤 다시 로그인하면 원래 화면으로 in tests/integration/test_session_persistence.py (AUTH-03, AUTH-01h, US8-5)
- [ ] T163 [P] [US8] Playwright 테스트를 쓴다. 글쓰기 중 세션을 지우고 발행 → 로그인 → 글쓰기 화면으로 돌아와 쓰던 내용이 남아 있음, 글 주소 복사 버튼이 바뀌지 않는 `/{blog}/{no}` 주소를 복사함 in tests/e2e/test_us8_writing.py (AUTH-03, COM-P06, SOC-02, US8-5)

### Implementation for User Story 8

- [ ] T164 [US8] 임시저장 서비스와 `PUT /api/drafts/current`를 만든다(`status=DRAFT`, `post_no` null, 발행하면 같은 행을 `publish_post`로) in apps/posts/api.py (POST-08)
- [ ] T165 [US8] 새 글 화면에 "이어 쓸까요?" 안내와 60초마다 서버 임시저장을 더한다 in static/js/editor.js (POST-08, COM-P06)
- [ ] T166 [US8] 대표 이미지 고르기(`cover_image_id`, 자기 이미지만)를 글 폼·서비스에 더하고 목록 대표 이미지를 `cover_image ?? first_image ?? 없음`으로 정한다 in apps/posts/services.py (POST-07)
- [ ] T167 [US8] 카테고리 서비스에 하위 한 단계·이동 제한·순서(`sort_order`)·상위 삭제 막기를 더하고, 사이드바·카테고리 목록에서 하위 포함 글과 글 수를 합친다 in apps/posts/categories.py (CAT-03, CAT-04)
- [ ] T168 [US8] 이전·다음 글을 `visible_posts`(주인은 `owner_posts`) 기준 `(published_at, id)` 앞뒤 한 개로 찾는다 in apps/posts/views.py (POST-10)
- [ ] T169 [US8] `GET /{blog}/tags` 태그 모아 보기 뷰와 템플릿을 만든다 in templates/posts/tags.html (TAG-03)
- [ ] T170 [US8] 로그인 유지를 설정한다(`SESSION_COOKIE_AGE` 14일, `SESSION_SAVE_EVERY_REQUEST=True`, 만료 뒤 `next` 복귀) in config/settings/base.py (AUTH-03)
- [ ] T171 [P] [US8] 글 상세에 이전·다음 글 링크와 글 주소 복사 버튼(`navigator.clipboard`, JS가 없으면 주소 글자 표시)을 넣는다 in templates/posts/post_detail.html (POST-10, SOC-02)
- [ ] T172 [P] [US8] 카테고리 관리 화면에 하위 카테고리와 순서 바꾸기(폼 전송)를 더한다 in templates/posts/manage_categories.html (CAT-03, CAT-04)

**Checkpoint**: 임시저장·대표 이미지·하위 카테고리·이전/다음 글이 동작하고, 로그인이 끊겨도 쓰던 글을 잃지 않는다

---

## Phase 11: User Story 9 - 구독과 피드 (Priority: P2)

**Goal**: 회원이 다른 블로그를 구독·해제하고, 구독한 블로그의 새 글을 피드에서 모아 본다

**Independent Test**: 회원 A가 블로그 B를 구독 → B가 글 발행 → A의 피드에 그 글이 보이는지, 구독자 수가 1인지 확인한다

### Tests for User Story 9 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 연타 중복과 자기 블로그 구독 막기는 특히 먼저다**

- [ ] T173 [P] [US9] 구독 테스트를 쓴다. 자기 블로그 `403 own_blog`, `PUT`·`DELETE /api/blogs/{address}/subscription`을 몇 번 보내도 행 0 또는 1, 동시 요청도 하나, 버튼에 구독 중 표시·다시 누르면 해제, 구독자 수가 실제 행 수, 삭제·이용 제한 블로그 404, `/me/subscriptions`에서 해제, JS 없는 `POST /{blog}/subscribe`·`unsubscribe` in tests/integration/test_subscriptions.py (SUB-01, SUB-03, COM-P06, SC-005, US9-1, US9-2)
- [ ] T174 [P] [US9] 피드 테스트를 쓴다. `/feed`가 구독한 블로그의 볼 수 있는 글 최신순(구독 이전 글 포함), 커서로 중복·누락 없음, 비공개 → 공개로 바꾼 글이 새 글로 나옴, 구독이 없으면 안내 + 다른 블로그를 둘러볼 링크, 비회원은 로그인으로 in tests/integration/test_feed.py (SUB-02, COM-P02, POST-06a, US9-3)

### Implementation for User Story 9

- [ ] T175 [US9] 구독 서비스를 더한다(`subscribe`: 자기 블로그면 `own_blog`, 유일 키 충돌은 성공; `unsubscribe`; 구독자 수 = 행 수) in apps/social/services.py (SUB-01, SUB-03)
- [ ] T176 [US9] 구독 API(`PUT`·`DELETE /api/blogs/{address}/subscription`)와 JS 없는 `POST /{blog}/subscribe`·`unsubscribe`를 만든다 in apps/social/api.py (SUB-01)
- [ ] T177 [US9] 피드 `GET /feed`, `GET /api/feed`, 구독 목록 `GET /me/subscriptions`·`POST /me/subscriptions/{address}/delete`를 만든다(`visible_posts` + 커서) in apps/social/views.py (SUB-01, SUB-02)
- [ ] T178 [P] [US9] 피드·구독 목록 템플릿을 만든다(빈 상태 안내와 홈 링크) in templates/social/feed.html (SUB-02)
- [ ] T179 [US9] 블로그 사이드바에 구독 버튼과 구독자 수를 넣고, `toggle.js`가 구독 버튼도 다루게 한다 in static/js/toggle.js (SUB-01, SUB-03)
- [ ] T180 [US9] 권한표 `matrix.py`에 구독·피드 행을 더하고 통과를 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: 구독·피드가 동작하고 구독자 수가 언제나 실제 값과 같다

---

## Phase 12: User Story 10 - 내 블로그 관리 (Priority: P2)

**Goal**: 블로그 주인이 글·댓글·방명록을 한곳에서 관리하고, 방문자는 방명록을 남긴다. 자기 댓글 수정과 회원 정보 수정도 여기서 더한다

**Independent Test**: 공개·비공개·임시저장 글이 섞인 블로그에서 글 관리 화면의 상태 구분과 공개 범위 전환을 확인한다

### Tests for User Story 10 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 댓글 수정 권한(작성자만)은 특히 먼저다**

- [ ] T181 [P] [US10] 글 관리 테스트를 쓴다. `/manage/posts?status=public|private|draft|hidden`이 상태별로 구분, 관리자가 숨긴 글은 숨김 상태와 사유 표시, 여기서 수정·삭제·공개 범위 변경(`POST /manage/posts/{no}/visibility`, 발행일 규칙대로) in tests/integration/test_manage_posts.py (MNG-01, COM-P02, US10-1)
- [ ] T182 [P] [US10] 댓글 관리 테스트를 쓴다. `/manage/comments`가 내 블로그의 모든 댓글·방명록 최신순, 댓글마다 어느 글인지, 여기서 삭제 in tests/integration/test_manage_comments.py (MNG-02, US10-2)
- [ ] T183 [P] [US10] 방명록 테스트를 쓴다. 회원만 작성(비회원 로그인 안내), 1~1,000자, 같은 `client_token`은 하나, 10초 간격, 작성자는 자기 것 수정·삭제, 블로그 주인은 모든 방명록 삭제(수정은 불가), 최신순 페이지, 삭제·이용 제한 블로그 404 in tests/integration/test_guestbook.py (CMT-04, COM-P06)
- [ ] T184 [P] [US10] 댓글 수정 테스트를 쓴다. `PATCH /api/comments/{id}`는 작성자만, 블로그 주인·관리자도 남의 댓글은 403, 길이 규칙 같음, `edited_at` 기록과 '수정됨' 표시 in tests/integration/test_comment_edit.py (CMT-03, CMT-02, ADMIN-01a)
- [ ] T185 [P] [US10] 회원 정보 테스트를 쓴다. `/me`에서 닉네임(2~20자, 중복 불가)과 회원 프로필 이미지 변경, 이미지 검사는 글 이미지와 같음, 바꾸면 이전 파일 삭제, 댓글 작성자 옆에 회원 프로필이 보이고 블로그 프로필과 섞이지 않음 in tests/integration/test_profile.py (AUTH-05, AUTH-01f)

### Implementation for User Story 10

- [ ] T186 [US10] 글 관리 뷰 `GET /manage/posts`와 `POST /manage/posts/{no}/visibility`를 만든다(`owner_posts(blog)`에서 상태별) in apps/posts/views.py (MNG-01)
- [ ] T187 [US10] 댓글 관리 뷰 `GET /manage/comments`를 만든다(댓글·방명록을 최신순으로 합쳐 페이지, 글 링크) in apps/comments/views.py (MNG-02)
- [ ] T188 [US10] 방명록 서비스·화면을 만든다. `GET /{blog}/guestbook`, `POST /{blog}/guestbook`, `POST /api/blogs/{address}/guestbook`, `PATCH`·`DELETE /api/guestbook/{id}`(규칙은 댓글 서비스와 같음) in apps/blogs/guestbook.py (CMT-04)
- [ ] T189 [US10] 댓글 수정 `PATCH /api/comments/{id}`(작성자만, `edited_at`)를 더한다 in apps/comments/api.py (CMT-03)
- [ ] T190 [US10] 내 정보 `GET, POST /me`(닉네임·회원 프로필 이미지, `apps/posts/images.py` 검사, 이전 파일 삭제)를 만든다 in apps/accounts/views.py (AUTH-05)
- [ ] T191 [P] [US10] 글 관리·댓글 관리 템플릿을 만든다(상태 배지, 숨김 사유, 삭제 확인 창) in templates/posts/manage_posts.html (MNG-01, MNG-02, COM-P04)
- [ ] T192 [P] [US10] 방명록 템플릿과 내 정보 템플릿을 만든다 in templates/blogs/guestbook.html (CMT-04, AUTH-05)
- [ ] T193 [US10] 댓글 스크립트에 자기 댓글 수정과 방명록 등록·삭제를 더한다 in static/js/comments.js (CMT-03, CMT-04)
- [ ] T194 [US10] 권한표 `matrix.py`에 글 관리·댓글 관리·방명록·댓글 수정·`/me` 행을 더하고 통과를 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: 블로그 주인이 글·댓글·방명록을 한곳에서 처리한다

---

## Phase 13: User Story 11 - 서비스 관리자의 제재 (Priority: P2)

**Goal**: 서비스 관리자가 회원 이용을 제한하고 글·댓글·방명록을 사유와 함께 숨긴다. 제재는 숨김이며 해제하면 원래대로 돌아온다

**Independent Test**: 관리자가 글을 사유와 함께 숨김 → 다른 사람에게 404, 글쓴이에게 숨김 사유가 보이는지 확인 → 해제 후 원래 위치·수치로 돌아오는지 확인한다

### Tests for User Story 11 ⚠️

> **NOTE: 먼저 쓰고, 실패하는 것을 확인한 뒤 구현한다. 제재 중 블로그·글이 모든 목록에서 빠지는지는 특히 먼저다**

- [ ] T195 [P] [US11] 이용 제한 테스트를 쓴다. 기간(날짜·영구)과 사유 필수, 제한된 회원은 로그인이 막히고 사유·기한 안내, 이미 로그인한 채 제한되면 다음 요청부터 로그아웃, 기한이 지나면 작업 없이 풀림, 기한 전 해제, 제한 중 그 블로그와 모든 글이 다른 사람에게 404이고 홈·검색·피드·순위·사이드바에서 빠짐, 풀리면 원래대로, 남의 글에 단 댓글은 그대로, 다른 서비스 관리자는 제한 불가(403) in tests/integration/test_sanctions.py (ADMIN-02, ADMIN-01a, POST-06a, SC-003, US11-1, US11-3)
- [ ] T196 [P] [US11] 숨김 테스트를 쓴다. 사유 필수, 숨긴 글은 다른 사람에게 404이고 모든 목록에서 빠짐, 글쓴이에게는 숨김 사실과 사유, 해제하면 같은 주소·발행일·공감·댓글·조회수·목록 위치로 돌아옴, 숨긴 댓글·방명록은 다른 사람에게 '관리자가 숨긴 댓글', 관리자 화면 `GET /admin/posts/{id}`에서만 대상 본문을 봄, 관리자는 내용을 고칠 수 없음 in tests/integration/test_hide_content.py (ADMIN-03, ADMIN-01a, POST-06a, US11-2)
- [ ] T197 [P] [US11] 관리 기록 테스트를 쓴다. 숨김·해제·제한·해제가 같은 트랜잭션에서 `admin_logs`에 남고, `AdminLog`는 수정·삭제가 막힘 in tests/unit/test_admin_logs.py (ADMIN-01a, ADMIN-03)

### Implementation for User Story 11

- [ ] T198 [US11] 제재 서비스를 만든다. `sanction_user`(대상이 `ADMIN`이면 거절), `release_user`, `hide_post`·`unhide_post`, `hide_comment`·`unhide_comment`, `hide_guestbook`·`unhide_guestbook`. 모두 한 트랜잭션에서 `hidden_by_id`와 `admin_logs`를 함께 쓴다 in apps/moderation/services.py (ADMIN-01a, ADMIN-02, ADMIN-03)
- [ ] T199 [US11] 이용 제한 미들웨어를 만든다(요청마다 제한 중인지 확인, 제한 중이면 로그아웃하고 사유·기한 화면으로) in apps/accounts/middleware.py (ADMIN-02)
- [ ] T200 [US11] 로그인 때 제한 중이면 막고 사유·기한을 안내하도록 어댑터를 고친다 in apps/accounts/adapters.py (ADMIN-02)
- [ ] T201 [US11] 관리 화면을 만든다. `GET /admin/users?q=`, `POST /admin/users/{id}/sanction`·`release`, `GET /admin/posts?q=`, `GET /admin/posts/{id}`, `POST /admin/posts/{id}/hide`·`unhide`, `POST /admin/comments/{id}/hide`·`unhide`, `POST /admin/guestbook/{id}/hide`·`unhide` in apps/moderation/views.py (ADMIN-02, ADMIN-03)
- [ ] T202 [P] [US11] 관리 화면 템플릿(사유 입력 필수, 기간 선택)을 만든다 in templates/moderation/users.html (ADMIN-02, ADMIN-03)
- [ ] T203 [US11] 댓글·방명록 조각과 API 응답에서 숨긴 항목을 '관리자가 숨긴 댓글'로 바꾸고, 글 상세·글 관리에서 주인에게 숨김 사유를 보여 준다 in templates/comments/_comments.html (ADMIN-03)
- [ ] T204 [US11] 권한표 `matrix.py`에 `/admin/...` 행을 더하고 통과를 확인한다 in tests/permissions/matrix.py (COM-01)

**Checkpoint**: P2 끝. 제재는 숨김이고 해제하면 원래대로 돌아온다

---

## Phase 14: User Story 12 - 확장 기능 (Priority: P3)

**Goal**: 여유가 있을 때 기능 하나씩 더한다. P3 테이블·열은 그 기능을 만들 때 마이그레이션으로 더하고, `tests/unit/test_no_p3_schema.py`에서 그 항목을 뺀다

**Independent Test**: 기능마다 따로 확인한다. 예: 정각 이후 홈 인기 블로거 순위와 랭킹 전체보기 순위가 같은 기준·같은 시점인지 확인한다

> **NOTE: 기능마다 테스트를 먼저 쓰고 실패를 확인한 뒤 구현한다. 공개 범위가 바뀌는 기능(예약 발행, 카테고리 비공개, 블로그 이용 제한)은 `tests/unit/test_visibility.py`에 경우를 먼저 더한다**

### 인기 블로거·랭킹 전체보기

- [ ] T205 [P] [US12] 인기 블로거 집계·랭킹 전체보기 테스트를 쓴다. 블로그 공개 글들의 직전 1시간 조회수 합계, 볼 수 없는 글 조회 제외, 공개 글이 없거나 이용 제한된 블로그 제외, 홈 상위 5개와 `/ranking?tab=posts|bloggers`가 같은 스냅숏 in tests/unit/test_blogger_rankings.py (HOME-04, HOME-05)
- [ ] T206 [US12] `compute_rankings`에 `kind=BLOGGER`(항목은 `blog_id`만)를 더하고, 홈 인기 블로거 영역과 `GET /ranking`을 만든다 in apps/discovery/rankings.py (HOME-04, HOME-05)

### 예약 발행

- [ ] T207 [P] [US12] 예약 발행 테스트를 쓴다. 정한 시각 전에는 주인이 아닌 사람에게 404이고 목록에 없음, 시각이 되면 자동 공개되고 그 시각이 발행일·그때 `post_no` 부여 in tests/integration/test_scheduled_posts.py (POST-13, COM-P02, US12-1)
- [ ] T208 [US12] `posts.scheduled_at DATETIME null`과 `status`의 `SCHEDULED`를 더하는 마이그레이션, 관리 명령 `publish_scheduled_posts`(1분마다, `deploy/crontab`), 글쓰기 화면 예약 칸을 만든다 in apps/posts/management/commands/publish_scheduled_posts.py (POST-13)

### 답글·비밀댓글·댓글 허용

- [ ] T209 [P] [US12] 답글·비밀댓글·댓글 막기 테스트를 쓴다. 답글은 한 단계까지, 답글이 달린 댓글을 지우면 '삭제된 댓글'(`tombstone: true`)로 남고 답글 유지, 비밀댓글은 블로그 주인과 작성자만 봄, 글마다 새 댓글 막기(`403 comments_closed`)와 기존 댓글 유지 in tests/integration/test_comment_threads.py (CMT-05, CMT-06, CMT-07, US12-2)
- [ ] T210 [US12] `comments.parent_id BIGINT null`·`is_secret BOOL`·`deleted_at DATETIME null`, `posts.is_comment_allowed BOOL`(기본 true) 마이그레이션과 댓글 서비스·API·화면 변경을 만든다 in apps/comments/services.py (CMT-05, CMT-06, CMT-07)

### 글 저장

- [ ] T211 [P] [US12] 글 저장 테스트를 쓴다. `PUT`·`DELETE /api/posts/{post_id}/save` 멱등, `/me/saved`에서 비공개·삭제된 글 제외 in tests/integration/test_saves.py (SOC-03)
- [ ] T212 [US12] `post_saves`(`(user_id, post_id)` 유일) 마이그레이션, 저장 API, `/me/saved` 화면을 만든다 in apps/social/models.py (SOC-03)

### 알림

- [ ] T213 [P] [US12] 알림 테스트를 쓴다. 내 글의 댓글·공감, 나를 구독함, 구독 블로그의 새 글이 알림으로 오고, 읽지 않은 수 표시, 누르면 해당 화면으로 가며 읽음, 내 행동으로는 나에게 알림이 오지 않음 in tests/integration/test_notifications.py (SUB-04, US12-3)
- [ ] T214 [US12] `notifications`(`type` "COMMENT \| LIKE \| SUBSCRIBE \| NEW_POST", `recipient`와 `actor`가 같으면 만들지 않음) 마이그레이션과 알림 서비스·`/me/notifications` 화면을 만든다 in apps/social/notifications.py (SUB-04)

### 맞구독·추천 블로그

- [ ] T215 [P] [US12] 맞구독·추천 테스트를 쓴다. 구독 버튼 네 상태(서로 안 함 / 상대만 나를 / 나만 / 서로), 맞구독 해제는 확인 후 내 구독만 취소하고 상대에게 알림 없음, 아직 구독하지 않은 인기 블로그 추천에서 자기 블로그 제외 in tests/integration/test_mutual_subscriptions.py (SUB-05, SUB-06)
- [ ] T216 [US12] 구독 API 응답에 `relation`을 더하고 버튼 네 상태와 추천 블로그 영역을 만든다 in apps/social/services.py (SUB-05, SUB-06)

### 블로그 꾸미기·삭제

- [ ] T217 [P] [US12] 블로그 꾸미기·삭제 테스트를 쓴다. 미리 만든 스킨 고르기, 상단 배경 이미지 올리기·지우기, HTML·CSS 직접 편집 없음, 확인 후 블로그 삭제(한 트랜잭션: 글·카테고리·태그·방명록·구독), 주소는 영구 예약, 다른 주소로 다시 개설 가능 in tests/integration/test_blog_skin_delete.py (BLOG-05, BLOG-07, BLOG-01b, COM-P04)
- [ ] T218 [US12] `blogs.skin VARCHAR(30)`, `blogs.header_image_id BIGINT null` 마이그레이션, 꾸미기 화면, `GET, POST /manage/settings/delete`를 만든다 in apps/blogs/views.py (BLOG-05, BLOG-07)

### 카테고리 비공개·태그 관리

- [ ] T219 [P] [US12] 카테고리 비공개·태그 관리 테스트를 쓴다. 비공개 카테고리의 글은 비공개 글과 똑같이 모든 목록·개수·주소에서 빠짐, 태그 이름 변경·삭제(연결만 끊기고 글은 남음) in tests/integration/test_private_category_tags.py (CAT-05, TAG-04, POST-06a)
- [ ] T220 [US12] `categories.is_private BOOL`(기본 false) 마이그레이션과 `visible_posts` 조건 5를 더하고, `GET, POST /manage/tags`를 만든다 in apps/posts/visibility.py (CAT-05, TAG-04)

### 방문 통계·차단·금칙어

- [ ] T221 [P] [US12] 방문 통계·차단 테스트를 쓴다. 오늘·어제·전체 방문자(하루 단위 고유 방문자 키)와 기간 내 많이 읽힌 내 글, 차단된 회원은 댓글·방명록을 쓸 수 없다는 사실만 안내(`403 blocked`), 금칙어가 든 댓글은 등록되지 않음 in tests/integration/test_stats_blocking.py (MNG-03, MNG-04)
- [ ] T222 [US12] `visit_stats`, `blog_blocked_users`, `blog_banned_words` 마이그레이션과 `GET /manage/stats`, 차단·금칙어 관리, 댓글 서비스 검사를 만든다 in apps/blogs/models.py (MNG-03, MNG-04)

### 신고·블로그 이용 제한·공지·이력·대시보드

- [ ] T223 [P] [US12] 신고·블로그 제한·공지 테스트를 쓴다. 남의 글·댓글을 사유를 골라 한 번만 신고(자기 것 불가), 관리자는 숨김·기각으로 처리하고 결과가 목록에 남음, 신고가 쌓여도 자동 숨김 없음, 블로그만 숨기면 메인과 모든 글이 다른 사람에게 404이고 주인에게 사유, 그 회원의 댓글은 그대로, 공지 작성, 대시보드 수치, 모든 제재·해제 기록은 수정·삭제 불가 in tests/integration/test_reports_notices.py (ADMIN-04, ADMIN-05, ADMIN-06, US12-4)
- [ ] T224 [US12] `reports`(`status` "PENDING \| HIDDEN \| DISMISSED", reporter + target 유일), `notices`, `blogs.restricted_at`·`restricted_reason`·`restricted_by_id` 마이그레이션, `visible_posts` 조건 2에 블로그 제한 추가, `/admin/reports`·`/admin/blogs/{id}/restrict`·`/admin/notices`·`/admin/logs`·대시보드를 만든다 in apps/moderation/views.py (ADMIN-04, ADMIN-05, ADMIN-06)

### 회원 탈퇴

- [ ] T225 [P] [US12] 탈퇴 테스트를 쓴다. 확인 후 탈퇴, 한 트랜잭션으로 블로그·글 삭제(주소 영구 예약), 공감·구독 삭제로 수치에서 빠짐, 남의 글 댓글·방명록은 '탈퇴한 회원', `email`·`nickname`·`profile_image` null(파일 삭제), 세션·allauth 행 삭제, 제재·관리 기록은 남음 in tests/integration/test_withdraw.py (AUTH-06, COM-P04)
- [ ] T226 [US12] `users.withdrawn_at DATETIME null` 마이그레이션과 `GET, POST /me/withdraw`, 탈퇴 서비스를 만든다 in apps/accounts/services.py (AUTH-06)

**Checkpoint**: 만든 P3 기능마다 테스트가 통과하고, 권한표·공개 범위 테스트에 새 경우가 들어갔다

---

## Phase 15: Polish & Cross-Cutting Concerns

**Purpose**: 여러 이야기에 걸친 마무리

- [ ] T227 [P] 구현 중 바뀐 명령·파일 이름을 quickstart.md에 반영한다 in specs/001-blog/quickstart.md (원칙 I)
- [ ] T228 [P] 이미지 정리·조회 기록 정리·만료 세션 정리 관리 명령 `cleanup`(24시간 넘게 어디에도 안 쓰인 이미지, 7일 지난 `post_views`)과 그 테스트를 만든다 in apps/core/management/commands/cleanup.py (COM-P03, POST-09)
- [ ] T229 [P] 모든 목록 화면(홈, 주제, 피드, 통합 검색, 글·댓글 관리)의 쿼리 수 테스트를 모아 글 10개·20개 비교를 확인한다 in tests/integration/test_query_counts.py (COM-P01, SC-007)
- [ ] T230 [P] 스크립트가 든 제목·본문·댓글·블로그 이름·소개·닉네임·태그를 만들고 모든 화면을 열어 실행 0건을 확인하는 Playwright 테스트를 쓴다 in tests/e2e/test_xss_all_pages.py (COM-P05, SC-010)
- [ ] T231 응답 시간을 잰다. 글 1만 개 시드에서 목록·상세 p95 300ms 이하, `compute_rankings`가 정각 후 5분 안에 끝남 in tests/integration/test_performance_budget.py (SC-006, SC-007)
- [ ] T232 [P] `deploy/backup.sh`로 백업한 것을 빈 DB에 복구해 보는 순서를 적고 한 번 해 본다 in deploy/backup.sh (COM-P06)
- [ ] T233 `make test`를 돌리고 quickstart.md 6절을 처음부터 끝까지 손으로 확인한다 in Makefile (원칙 V, SC-002)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 바로 시작할 수 있다
- **Foundational (Phase 2)**: Setup이 끝나야 한다. **모든 이야기를 막는다**. 그 안에서는 `User` 모델과 첫 마이그레이션이 다른 모델보다 먼저다
- **P1 이야기 (Phase 3~8)**: 기반이 끝나야 한다. 원칙 VI에 따라 P1 한 바퀴(US1~US6)가 끝나기 전에 P2를 시작하지 않는다
- **P2 이야기 (Phase 9~13)**: P1 체크포인트(Phase 8 끝)가 지나야 한다
- **P3 (Phase 14)**: P2가 끝난 뒤, 기능 묶음 하나씩
- **Polish (Phase 15)**: 원하는 이야기가 끝난 뒤

### User Story Dependencies

- **US1 (P1)**: 기반 뒤 바로. 다른 이야기에 기대지 않는다
- **US2 (P1)**: 블로그가 있어야 글을 쓰므로 US1의 개설(`/blog/new`, `blog_owner_required`)에 기댄다
- **US3 (P1)**: US2의 글이 있어야 목록을 확인한다. 사이드바·검색은 독립적으로 만들 수 있다
- **US4 (P1)**: US2의 발행에 기댄다. US3와 함께 진행할 수 있다
- **US5 (P1)**: US2의 글 상세에 기댄다. US3·US4와 함께 진행할 수 있다
- **US6 (P1)**: 권한표 전체와 P1 한 바퀴 E2E를 확인하므로 US1~US5 뒤에 끝난다(테스트는 먼저 써 둘 수 있다)
- **US7 (P2)**: US4 홈에 영역을 더한다
- **US8 (P2)**: US2 에디터·US3 카테고리에 기능을 더한다
- **US9 (P2)**: US4 커서 목록을 피드에 쓴다
- **US10 (P2)**: US2 글·US5 댓글에 관리 화면을 더한다
- **US11 (P2)**: 기반의 `visible_posts` 이용 제한 조건과 US10 글 관리(숨김 사유 표시)에 기댄다
- **US12 (P3)**: 기능 묶음마다 해당 P1·P2 이야기 뒤

### Within Each User Story

- 테스트를 먼저 쓰고 **실패를 확인**한 뒤 구현한다(원칙 V)
- 모델·서비스 → 뷰·API → 템플릿·JS 순서
- 이야기마다 마지막에 권한표 `matrix.py` 행을 채우고 통과를 확인한다
- 이야기가 끝나면 체크포인트에서 혼자 시연해 본다

### Parallel Opportunities

- Setup의 [P] 작업은 함께 할 수 있다
- 기반에서 `User` 모델·첫 마이그레이션 뒤 앱별 모델 작업([P])과 테스트 작업([P])을 함께 할 수 있다
- 이야기 안의 [P] 테스트는 모두 함께 쓸 수 있다
- US3·US4·US5는 US2 뒤 함께 진행할 수 있다(파일이 다르다). 단, `tests/permissions/matrix.py`와 `templates/posts/post_detail.html`은 한 사람씩 고친다
- P2의 US8·US9·US10은 서로 다른 앱이 많아 함께 진행할 수 있다

---

## Parallel Example: User Story 1

```bash
# US1 테스트를 함께 쓴다 (모두 실패해야 한다):
Task: "이메일 가입 테스트 in tests/integration/test_signup_email.py"
Task: "이메일 로그인 테스트 in tests/integration/test_login.py"
Task: "비밀번호 재설정 테스트 in tests/integration/test_password_reset.py"
Task: "소셜 가입 테스트 in tests/integration/test_social_signup.py"
Task: "블로그 주소 검사 단위 테스트 in tests/unit/test_blog_address.py"
Task: "예약어·URL 일치 테스트 in tests/unit/test_reserved_words.py"
Task: "블로그 개설 테스트 in tests/integration/test_blog_create.py"

# 서로 다른 파일의 구현을 함께 한다:
Task: "가입 폼 in apps/accounts/forms.py"
Task: "예약어 상수 in apps/blogs/reserved.py"
Task: "블로그 주소 검사 함수 in apps/blogs/validators.py"
Task: "소셜 가입 템플릿 in templates/socialaccount/signup.html"
Task: "/terms, /privacy in apps/core/views.py"
```

## Parallel Example: User Story 2

```bash
# US2 테스트를 함께 쓴다 (중복 처리·비공개 404 포함, 모두 실패해야 한다):
Task: "본문 정제 단위 테스트 in tests/unit/test_sanitize.py"
Task: "발행 규칙 단위 테스트 in tests/unit/test_post_rules.py"
Task: "발행 통합 테스트 in tests/integration/test_post_publish.py"
Task: "동시 발행 테스트 in tests/integration/test_post_number_concurrency.py"
Task: "수정·삭제 테스트 in tests/integration/test_post_edit_delete.py"
Task: "이미지 업로드 테스트 in tests/integration/test_image_upload.py"

# 서로 기대지 않는 도우미를 함께 만든다:
Task: "nh3 정제 함수 in apps/posts/sanitize.py"
Task: "Pillow 이미지 함수 in apps/posts/images.py"
Task: "태그 이름 정리 함수 in apps/posts/tags.py"
Task: "에디터 스타일 in static/css/editor.css"
```

---

## Implementation Strategy

### MVP First (P1 한 바퀴)

1. Phase 1 Setup을 마친다
2. Phase 2 Foundational을 마친다(모든 이야기를 막는다)
3. Phase 3~8, US1~US6을 차례로 마친다
4. **멈추고 확인한다**: `make test` 통과, quickstart 6절 손 확인. 두 회원이 "가입 → 개설 → 발행 → 홈에서 발견 → 읽기·댓글·공감"을 막힘 없이 돈다(SC-002)
5. 여기까지가 MVP다. 배포하거나 시연한다

US1 하나만으로는 글이 없어 MVP가 되지 않는다. spec이 정한 P1 범위(US1~US6)가 한 바퀴의 최소 단위다.

### Incremental Delivery

1. Setup + Foundational → 기반 준비
2. US1 → US2 → US3·US4·US5 → US6 → P1 MVP 시연
3. US7(발견 넓히기) → 시연
4. US8·US9·US10(쓰기 편의, 구독, 관리) → 시연
5. US11(제재) → P2 끝, 시연
6. US12의 P3 기능을 하나씩 더한다. 기능마다 마이그레이션·테스트·화면을 한 PR로

### 혼자 진행할 때

이 프로젝트는 민주 혼자 만든다(constitution 원칙 VI). [P] 표시는 "순서를 바꿔도 된다"는 뜻으로 읽고, 한 이야기를 끝내고 다음 이야기로 간다. 구현 PR은 이야기 하나나 기능 ID 묶음 하나로 작게 나눈다.

---

## Notes

- [P] = 다른 파일이고 끝나지 않은 작업에 기대지 않음
- [Story] = spec 사용자 이야기와 이어 주는 표시(원칙 I)
- 테스트마다 `@pytest.mark.req("<요구사항 ID>")`와 수용 시나리오 ID(`US2-8` 등)를 단다
- 테스트가 실패하는 것을 먼저 확인한다
- 작업이나 작은 묶음마다 커밋하고, 커밋 메시지에 요구사항 ID를 적는다
- 체크포인트마다 멈추고 이야기를 혼자 확인한다
- 피할 것: 모호한 작업, 같은 파일을 동시에 고치기, 이야기 독립성을 깨는 의존
