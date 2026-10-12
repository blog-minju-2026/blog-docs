# Research: 한채 블로그 플랫폼 기술 결정

**Feature**: `001-blog` | **Date**: 2026-10-08 | **Plan**: [plan.md](./plan.md)

`/speckit.plan` Phase 0 결과다. 민주가 정한 조건은 **화면 HTML·CSS·JavaScript, 서버 Python** 두 가지이고, 나머지는 아래 추천안으로 정했다. 각 항목은 결정 → 이유 → 검토한 대안 순서로 적는다.

선택 기준은 [constitution](../../.specify/memory/constitution.md)에서 가져왔다.

1. **단순한가** (원칙 VI). 서버가 HTML을 그려 보내고, 새 도구는 이유가 있을 때만 들인다. 혼자 만들고 유지할 수 있어야 한다.
2. **안전이 기본값인가** (원칙 II·III). 이스케이프, CSRF, 비밀번호 해시, 권한 검사를 손으로 다 짜지 않아도 되는 쪽을 고른다.
3. **데이터가 어긋나지 않는가** (원칙 IV). DB 제약과 트랜잭션으로 중복·반쪽 처리를 막을 수 있어야 한다.
4. **팀 문서와 맞는가**. 팀 ERD 파트 분담 컨벤션은 MySQL이다(민주 파트 2 DDL `erd_part2.sql`).

2026-10-07 초안(PR #2, 닫힘)을 바탕으로, 그 뒤 바뀐 spec(요구사항 ID 변경, 검토 반영 결정 16건)과 constitution v1.0.0에 맞춰 고쳤다. 초안과 달라진 결정은 맨 끝 '초안에서 바뀐 것'에 모았다.

---

## 1. 서버 프레임워크

- **Decision**: **Django 5.2 LTS** (Python 3.13)
- **Rationale**:
  - 템플릿으로 서버가 HTML을 그려 보내는 방식이 기본이라 원칙 VI와 기술 제약(HTML·CSS·JS + Python)에 그대로 맞는다. 프론트엔드 빌드 도구가 필요 없다.
  - 회원·세션·비밀번호 해시, ORM과 마이그레이션(원칙 IV "DB 구조 변경은 마이그레이션 파일로만"), 폼 검증, 관리 도구가 들어 있다.
  - 템플릿이 기본으로 이스케이프하고 CSRF 방어가 기본으로 켜져 있다(원칙 III, COM-P05).
  - 5.2는 장기 지원판으로 2028년 4월까지 보안 패치가 나온다.
- **Alternatives considered**:
  - **Flask**: 회원, ORM, 마이그레이션, CSRF, 폼 검증을 각각 확장으로 붙여야 한다. 요구사항 100여 개 규모에서 붙일 부품이 많아 원칙 VI에 오히려 어긋난다.
  - **FastAPI**: JSON API 중심이라 화면을 JS로 따로 그려야 한다. "JS가 꺼져도 읽기와 목록은 동작"(원칙 VI)을 지키기 어렵다.
  - **Django 6.x**: LTS가 아니고 지원 기간이 짧다. 다음 LTS(6.2)가 나오면 올린다.

## 2. 화면 방식

- **Decision**: **Django 템플릿(서버 렌더링) + 순수 CSS + 순수 JavaScript(ES 모듈)**. 빌드 도구·CSS 프레임워크 없음.
- **Rationale**:
  - 모든 화면이 JS 없이 열린다. JS는 원칙 VI가 꼽은 곳(공감·구독 버튼, 입력 확인, 이미지 올리기)과 에디터, '더 불러오기'에만 쓴다. JS가 없으면 '더 불러오기'는 다음 페이지 링크로, 댓글 등록은 폼 전송으로 동작한다.
  - 주소마다 서버가 완성된 HTML을 주므로 새로고침·공유·뒤로 가기가 그대로 동작한다(SRCH-01 "결과에도 주소가 있어").
  - 모바일 우선 CSS(360px부터) + 넓은 화면 미디어 쿼리로 SC-008을 맞춘다. 좁은 화면의 블로그 사이드바는 `<details>`로 접어 본문 아래에 둔다(JS 불필요).
- **Alternatives considered**:
  - **React·Vue SPA**: 빌드 과정이 생기고 JS 없이 읽기가 안 된다. 원칙 VI 위반.
  - **htmx**: 서버 렌더링과 잘 맞지만, 위 몇 곳은 `fetch` 몇 줄로 되므로 라이브러리를 더할 이유가 아직 없다. 반복이 많아지면 그때 plan을 고쳐 검토한다.
  - **Bootstrap·Tailwind**: 디자인 언어를 처음부터 묶는다. 테마는 디자인 단계에서 정하기로 했다(spec Assumptions).

## 3. 데이터베이스

- **Decision**: **MySQL 8.4 LTS**. 문자셋 `utf8mb4`, 정렬 규칙 **`utf8mb4_0900_as_ci`**(대소문자 무시, 악센트 구분).
- **Rationale**:
  - 팀 ERD 컨벤션과 민주의 파트 2 DDL이 MySQL 기준이라 그대로 옮겨 쓸 수 있다.
  - `as_ci` 정렬에서는 영문 대소문자만 다른 문자열이 같은 값이다. 그래서 "대소문자만 다르면 같은 태그"(TAG-01), "닉네임은 겹칠 수 없다"(AUTH-01f), "검색은 대소문자 무시"(SRCH-01)를 **유일 키와 비교 연산이 그대로 지킨다**(원칙 IV). `ai_ci`(악센트까지 무시)는 `café`와 `cafe`를 같은 태그로 만들어 spec보다 넓으므로 쓰지 않는다.
  - 생성 열(generated column)로 "살아 있는 블로그는 회원당 하나" 같은 조건부 유일 제약을 표현할 수 있다([data-model.md](./data-model.md) 3절).
  - 8.4는 장기 지원판이다(8.0은 2026년 4월 지원 종료). Django 5.2가 지원한다.
- **Alternatives considered**:
  - **SQLite**: 설치가 없어 쉽지만, 정각 집계와 웹 요청이 동시에 쓸 때 잠금 문제가 생기고 정렬 규칙이 운영과 달라진다.
  - **PostgreSQL**: 부분 유니크 인덱스가 있어 설계는 더 깔끔하지만 팀 컨벤션과 다르다. 대소문자 무시 유일 키에 `citext`나 함수 인덱스가 필요하다.

## 4. 회원·인증 (이메일 + 카카오·구글·네이버)

- **Decision**: **django-allauth 65.x**로 이메일 가입·인증·재설정과 소셜 로그인 세 곳을 처리한다. 비밀번호 해시는 **Argon2**(`argon2-cffi`).
- **Rationale**: 세 제공사를 모두 기본 지원하고, spec이 요구하는 동작 대부분이 설정이다.

  | spec | allauth에서 |
  | --- | --- |
  | AUTH-01a 메일 인증 필수, 중복 이메일 불가, 8자 이상 | `ACCOUNT_EMAIL_VERIFICATION="mandatory"`, `ACCOUNT_UNIQUE_EMAIL=True`, `AUTH_PASSWORD_VALIDATORS` 최소 길이 8 |
  | AUTH-01b 무엇이 틀렸는지 구분하지 않음 | allauth 기본 문구 하나("이메일 또는 비밀번호가 맞지 않습니다")로 번역을 고정 |
  | AUTH-01c 한 번만, 시간 제한 재설정 링크 | allauth 기본 재설정 흐름(토큰은 비밀번호가 바뀌면 무효) |
  | AUTH-01g 연속 실패 시 잠시 막기 | `ACCOUNT_RATE_LIMITS["login_failed"]` (값은 14절) |
  | AUTH-01h 원래 화면으로 복귀 | `next` 파라미터(같은 사이트 주소만 허용) |
  | AUTH-01 소셜 첫 로그인 때 동의·닉네임 한 화면 | `SOCIALACCOUNT_AUTO_SIGNUP=False` + 소셜 가입 폼(`SOCIALACCOUNT_FORMS["signup"]`)에 동의 칸과 닉네임(제공사 닉네임으로 미리 채움)을 둔다 |
  | AUTH-01e 필수 동의 2개, 만 14세 미만 불가 | 이메일 가입 폼과 소셜 가입 폼에 같은 동의 칸 3개(이용약관, 개인정보 수집·이용, 만 14세 이상 확인)를 넣는 공통 믹스인 |

- **AUTH-01d (같은 이메일, 다른 방식)**: allauth의 계정 자동 연결은 끈다(`SOCIALACCOUNT_EMAIL_AUTHENTICATION=False`, `..._AUTO_CONNECT=False`). 사용자 정의 어댑터에서 두 방향을 모두 막는다.
  - 소셜 첫 로그인(`pre_social_login`): 제공사가 준 이메일이 이미 다른 방식으로 가입돼 있으면 가입을 멈추고, 로그인 화면에 "이 이메일은 ○○(으)로 가입돼 있습니다. ○○(으)로 로그인해 주세요"를 띄운다.
  - 이메일 가입: 그 이메일이 소셜 회원 이메일이면 같은 안내를 하고 가입하지 않는다(이메일 열의 유일 키가 최종 방어선).
  - 제공사가 이메일을 주지 않으면 이 검사를 건너뛰고 이메일 없이 가입시킨다(AUTH-01).
- **Alternatives considered**:
  - **Django 기본 auth + 제공사별 OAuth 직접 구현**: 세 곳의 인증 흐름·토큰 검증을 직접 짜야 해 보안 실수 위험이 크다(원칙 III).
  - **Authlib**: 범용 OAuth 클라이언트라 가입·메일 인증·재설정 화면을 직접 만들어야 한다.
- **구현 전에 확인할 것**:
  - **카카오**: 이메일 동의 항목은 비즈 앱에서만 받을 수 있다. 못 받으면 이메일 없이 가입된다.
  - **네이버**: 개발 중에는 등록한 테스트 계정만 로그인된다. 공개하려면 검수가 필요하다.
  - 세 곳 모두 콜백 주소(`/accounts/{provider}/login/callback/`)를 개발용·운영용으로 각각 등록한다. 키는 환경 변수로만 넣는다(원칙 III).

## 5. WYSIWYG 에디터와 본문 정제

- **Decision**: **Quill 2** (BSD 라이선스). 빌드 없이 `static/vendor/quill/`에 파일로 넣는다. 저장 형식은 HTML. 서버는 저장 전에 **nh3**로 허용 목록 정제를 한다.
- **Rationale**:
  - POST-01b가 요구하는 문단 제목·굵게·기울임·글자색·정렬·목록·인용·코드 블록·링크·이미지를 기본 툴바로 모두 지원한다. 동영상 버튼은 툴바에서 뺀다.
  - 이미지 버튼을 가로채 서버 업로드 API로 올리고 받은 주소를 커서 위치에 넣는다(POST-05). 여러 장은 고른 순서대로 하나씩 올려 넣는다.
  - 라이선스 키가 필요 없다.
- **허용 목록**(원칙 III, COM-P05, SC-010):
  - 태그: `p h2 h3 strong em u s span a ol ul li blockquote pre code img br`
  - `a[href]`: `http`·`https`만. 저장할 때 `target="_blank" rel="noopener noreferrer nofollow"`를 강제로 붙인다(POST-01b 외부 링크 새 창).
  - `img[src]`: 이 서비스의 이미지 주소(`/media/...`)만. 외부 이미지 주소는 지운다.
  - `class`: `ql-align-*`, `ql-syntax`만. `style`: `color`만.
  - 그 밖의 태그는 내용만 남기고 지우고, `<script>` `<style>` `<iframe>`은 내용째 지운다.
- **정제 단계에서 함께 만드는 값**: 서식을 뺀 순수 텍스트(`content_text`, 검색용), 앞 150자 요약(`excerpt`, COM-P01), 본문 첫 이미지(`first_image_id`, POST-07), 빈 본문 여부(POST-01a: 텍스트가 공백뿐이고 이미지가 없으면 빈 본문).
- **Alternatives considered**:
  - **TinyMCE 7·CKEditor 5**: 최신판이 GPL 또는 상용 라이선스이고 키 설정이 필요하다.
  - **Toast UI Editor**: 마크다운 중심이고 유지보수가 거의 멈췄다.
  - **Tiptap**: npm 빌드가 사실상 필요하다(원칙 VI).
  - **bleach**: 더 이상 개발되지 않는다. nh3가 그 후속으로 쓰인다.

## 6. 이미지 업로드

- **Decision**: **Pillow**로 파일을 열어 실제 형식을 확인하고, 파일당 **10MB** 상한. 저장은 서버 디스크(`MEDIA_ROOT`), 웹 서버(Caddy)가 직접 내려준다.
- **Rationale**:
  - 확장자·MIME이 아니라 Pillow가 연 결과로 jpg·png·gif·webp인지 판단한다(원칙 III, COM-P03).
  - JPEG는 EXIF 방향을 반영해 다시 저장한다(휴대폰 사진 방향). GIF·PNG·WEBP는 원본 그대로 저장해 GIF 움직임을 지킨다.
  - 목록용 작은 이미지(가로 480px)를 올릴 때 함께 만든다(COM-P03 "목록에서는 작게"). 움직이는 GIF는 원본 비율로 첫 장면만 작게 만들고, 움직임은 글 상세의 원본에서 보인다.
  - 파일 이름은 서버가 만든 무작위 이름(UUID). 올린 사람의 파일 이름은 저장하지 않는다.
- **Alternatives considered**: **S3 같은 객체 저장소(django-storages)**: 서버가 여러 대가 되거나 디스크가 모자랄 때로 미룬다. 코드는 Django storage API만 써서 나중에 설정으로 바꿀 수 있게 한다.

## 7. 정각 집계와 정기 작업

- **Decision**: Django **관리 명령**을 서버 **cron**이 실행한다.
  - `compute_rankings`: 매시 0분. 인기 글(P2), 인기 블로거(P3).
  - `cleanup`: 매일 새벽. 7일 지난 조회 기록, 24시간 넘게 어디에도 안 쓰인 이미지, 만료된 세션 정리.
  - `publish_scheduled_posts`: 1분마다(P3).
- **Rationale**: 별도 작업 서버(Celery, Redis)가 필요 없고, 집계 로직이 웹 앱 코드 안에 있어 테스트하기 쉽다(원칙 V·VI). 순위 스냅숏은 `(종류, 기준 정각)`에 유일 키를 걸어 같은 정각에 두 번 돌아도 한 번만 저장된다(원칙 IV). 0분 실행 + 수 초 집계로 SC-006(5분 안)을 맞춘다.
- **집계 구간**: `HH:00` 순위 = `(HH-1):00 ≤ 조회 시각 < HH:00`. 1시간 조회가 0건이면 `HH-24:00 ~ HH:00`으로 다시 세고, 그것도 0건이면 빈 상태로 저장한다(HOME-02). 동점은 발행일이 늦은 글이 위.
- **Alternatives considered**:
  - **Celery + Redis**: 서비스가 두 개 늘어난다. 지금 규모에 과하다.
  - **웹 프로세스 안의 APScheduler**: 웹 프로세스가 여러 개면 중복 실행되고 재시작하면 일정이 꼬인다.
- 이용 제한 기한 만료(ADMIN-02)는 작업 없이, 요청 때마다 `ends_at`과 현재 시각을 비교해 판단한다.

## 8. 조회수 중복 방지 (POST-09)

- **Decision**: 같은 **방문자 키**가 같은 글을 **30분** 안에 다시 열면 세지 않는다.
  - 방문자 키: 회원이면 회원 ID, 비회원이면 서명된 무작위 쿠키(1년). 쿠키가 없으면 IP + User-Agent. 어느 쪽이든 서버 비밀 값을 섞은 SHA-256으로 바꿔 저장한다(원래 값은 남기지 않음).
  - 이름에 `bot`, `crawler`, `spider`가 들어간 User-Agent는 세지 않는다.
  - 블로그 주인 본인의 조회도 센다. spec에 제외 규칙이 없기 때문이다(원칙 I). 빼고 싶으면 spec을 먼저 고친다.
- **Rationale**: "짧은 시간"(Clarifications)을 30분으로 정했다. 1시간 순위 구간보다 짧아야 정상 재방문이 순위에 반영된다.
- **구현**: 글 상세 요청 때 `post_views`에서 `(post_id, viewer_key, viewed_at > 지금-30분)`을 찾고, 없을 때만 조회 기록을 넣고 `posts.view_count`를 1 올린다. 둘은 한 트랜잭션이다(원칙 IV).

## 9. 중복 요청과 숫자 정합성 (COM-P06, SC-005)

- **Decision**:
  - **글 발행·댓글·방명록 등록**: 화면을 열 때 일회용 토큰(UUID)을 숨은 칸에 넣고, `(작성 주체, client_token)` 유일 키를 건다. 같은 토큰으로 두 번 오면 처음 만든 것을 돌려준다.
  - **공감·구독**: "누르면 뒤집기"가 아니라 **원하는 상태를 보내는** API(`PUT` 켜기, `DELETE` 끄기). `(회원, 대상)` 유일 키가 있어 연타해도 행은 하나다. 버튼은 요청 중 잠근다(보조).
  - **숫자**: 공감 수·댓글 수·구독자 수·카테고리별 글 수는 따로 저장하지 않고 **매번 실제 행을 센다**. 목록에서는 `annotate`로 한 쿼리에 함께 세어 N+1을 피한다(기술 제약). 따로 저장하지 않으니 탈퇴·숨김·삭제 때 맞춰 줄 곳이 없다. 조회수만 열(`view_count`)로 둔다.
- **Alternatives considered**: 수치를 열로 두고 같은 트랜잭션에서 갱신하는 방식(원칙 IV가 허용)은 맞춰 줄 곳이 많아 실수하기 쉽다. 규모가 커져 느려지면 그때 바꾼다.

## 10. 권한과 공개 범위 판단 (원칙 II)

- **Decision**: 공개 범위는 **한 모듈**(`apps/posts/visibility.py`)에서만 판단한다.
  - `visible_posts(viewer)`: 볼 수 있는 글의 쿼리셋. 블로그 글 목록·카테고리·태그·블로그 검색·통합 검색·홈·주제별 글·인기 글(표시할 때)·인기 블로거 집계·피드·사이드바 글 수·이전/다음 글·저장 목록이 **모두 이것에서 시작한다**. 화면 코드에 `visibility=`나 `hidden_at` 조건을 직접 쓰지 않는다(코드 검사로 확인: 17절).
  - `get_post_for_viewer_or_404(blog_address, post_no, viewer)`: POST-04a 순서(존재 → 블로그 소속 → 블로그 이용 제한 → 관리자 숨김 → 블로그 주인 여부 → 공개 범위·상태) 그대로 판단하고, 볼 수 없으면 404.
  - 화면 권한은 데코레이터 세 개(`login_required`, `blog_owner_required`, `service_admin_required`)로 건다. 권한표(COM-01)는 테스트 데이터 표로 옮겨, 네 상태 × 모든 ✕ 칸을 매개변수 테스트가 돈다(원칙 V, SC-004).
- **서비스 관리자의 비공개 글 읽기**(권한표 "제재에 필요한 범위"): 관리 영역(`/admin/...`)의 숨김·제재 화면에서만 대상 글 본문을 보여 준다. 블로그 화면(`/{blog}/{no}`)에서는 관리자도 일반 회원과 똑같이 404다.

## 11. 검색 (SRCH-01, SRCH-02)

- **Decision**: **부분 일치 `LIKE '%검색어%'`**. 대상은 제목, `content_text`(서식 뺀 본문), 태그 이름. 검색어는 앞뒤 공백을 빼고 최대 100자로 자르며, `%`·`_`는 이스케이프한다. 대소문자는 정렬 규칙(3절)이 무시한다.
  - **정확도순**(SRCH-02): 제목에 있으면 3점, 태그에 있으면 2점, 본문에만 있으면 1점. 같은 점수는 최신순.
  - **블로그 결과**(SRCH-02): 블로그 이름·소개에 부분 일치. 이용 제한·삭제된 블로그는 빠진다.
- **Rationale**: spec은 "검색어가 들어 있는 글을 모두 찾는 부분 일치"다. MySQL ngram 전문 검색은 2글자 단위로 쪼개 한 글자 검색이 안 되고, 결과가 부분 일치와 미묘하게 달라 spec과 어긋난다. 첫해 규모(글 1만 개)에서는 전체 훑기로도 충분하다(원칙 VI).
- **Alternatives considered**:
  - **MySQL ngram FULLTEXT**: 빠르지만 위 이유로 결과가 spec과 다르다. 글이 10만 개를 넘어 느려지면 "후보를 FULLTEXT로 좁힌 뒤 LIKE로 확인"으로 바꾼다.
  - **Elasticsearch·OpenSearch**: 서비스가 하나 늘어난다.

## 12. 목록 나누기

- **Decision**:
  - 블로그 글 목록·카테고리·태그·블로그 검색·통합 검색: **페이지 번호**(`?page=N`), 한 페이지 10개(COM-P01). 마지막을 넘으면 빈 목록 `200`.
  - 홈 최신 글·주제별 글·구독 피드: **커서** 방식 '더 불러오기'. 커서는 마지막 글의 `(published_at, id)`. 위에 새 글이 생겨도 중복·누락이 없다(HOME-01a, SUB-02). JS가 없으면 같은 커서를 쓰는 "다음" 링크가 된다.
  - 정렬은 언제나 `published_at DESC, id DESC`(같은 시각이면 나중에 만든 글이 위, COM-P01).

## 13. 테스트 (원칙 V)

- **Decision**: **pytest + pytest-django**(단위·통합), **Playwright for Python**(브라우저 E2E), **ruff**(검사·서식). 테스트 DB도 MySQL 8.4(정렬 규칙·생성 열이 운영과 같아야 함).
- **요구사항 ID 표기**: 테스트마다 `@pytest.mark.req("POST-04a")` 표시를 단다. `pytest -m` 대신 `pytest --req POST-04a`로 한 요구사항의 테스트만 돌릴 수 있게 `conftest.py`에 작은 옵션을 둔다. 수용 시나리오는 `US2-8` 같은 이름도 함께 단다.
- **권한표 테스트**: COM-01 표를 `tests/permissions/matrix.py`에 데이터로 옮기고, 비회원·회원·블로그 주인·서비스 관리자 네 상태로 모든 ✕ 칸을 주소 직접 요청으로 시도한다(SC-004). 이 테스트와 공개 범위·중복 처리 테스트는 구현보다 먼저 쓴다.
- **명령 하나**: `make test`가 ruff 검사, 단위·통합, E2E(크로미움·웹킷)를 차례로 모두 돌린다(원칙 V). 개발 중에는 `uv run pytest`(단위·통합만)나 `uv run pytest --req POST-04a`처럼 일부만 돌려도 된다. 병합 전 확인과 CI는 `make test` 하나다.
- **Rationale**: Playwright 하나로 크로미움(크롬·엣지)·웹킷(사파리) 엔진과 360px 화면을 확인할 수 있다(SC-008, SC-009).
- **Alternatives considered**: **factory_boy**(테스트 데이터 생성)는 편하지만 필수는 아니다. pytest 픽스처 함수로 시작하고, 반복이 많아지면 plan을 고쳐 들인다(원칙 VI). **Selenium**: 브라우저 드라이버 관리가 번거롭다.

## 14. 통합본 '자율' 값과 plan으로 넘어온 값

spec Assumptions와 review.md 5장에서 plan으로 넘긴 값이다. 구현 중 바꿔도 되는 설정값(`config/settings/base.py`)으로 둔다.

| 항목 | 값 | 근거 |
| --- | --- | --- |
| 이미지 크기 상한 | 파일당 10MB | 휴대폰 원본 사진이 대부분 들어가는 크기 |
| 글당 이미지 수 상한 | 50장 | review C-02. 넘으면 이유를 알린다 |
| 본문 길이 상한 | 정제 후 HTML 1MB | review C-02 |
| 로그인 유지 기간 | 14일, 요청할 때마다 연장 | AUTH-03 |
| 로그인 실패 제한 | 같은 이메일 5분 안 5회 실패 → 5분 막음. 같은 IP 1분 20회 | AUTH-01g. 횟수 기록은 DB 캐시 |
| 이메일 인증 링크 | 3일, '다시 보내기' 제공 | review A-06 |
| 비밀번호 재설정 링크 | 1시간, 한 번만 | AUTH-01c |
| 비밀번호 상한 | 128자. Django 기본 검사기로 흔한 비밀번호·이메일과 비슷한 비밀번호 거절 | review A-09 |
| 조회수 중복 판단 | 같은 방문자·같은 글 30분 | 8절 |
| 자동 임시저장 | 브라우저 백업(localStorage) 입력 2초 뒤마다, 서버 임시저장 60초마다(P2) | COM-P06 "쓰던 내용을 잃지 않음" |
| 검색어 길이 | 앞뒤 공백 뺀 1~100자 | review G-03. 한 글자 검색 허용 |
| 블로그당 카테고리 수 | 100개 | review D-05 |
| 댓글 등록 간격 | 회원당 10초에 1개 | review E-05. MNG-04(P3) 전 최소 방어 |
| 방문자 집계(P3) | 블로그별 하루 단위 고유 방문자 키 수 | MNG-03 |
| 홈 노출 개수 | 인기 글 10, 인기 블로거 5(P3), 주제별 6, 최신 글 한 번에 20 | **잠정값.** 원본대로 홈 디자인 후 다시 정한다 |
| 블로그 주소 예약어 | [contracts/pages.md](./contracts/pages.md) 끝 목록 | review B-02 |

## 15. 주제 목록 (POST-11)

spec에서 10개로 확정했다. 주소에 쓸 이름(slug)만 여기서 정한다.

| 순서 | 주제 | slug |
| --- | --- | --- |
| 1 | 일상 | `daily` |
| 2 | 여행·맛집 | `travel-food` |
| 3 | IT·개발 | `it-dev` |
| 4 | 문화·연예 | `culture` |
| 5 | 책·영화 | `books-movies` |
| 6 | 반려동물 | `pets` |
| 7 | 요리 | `cooking` |
| 8 | 스포츠 | `sports` |
| 9 | 경제·재테크 | `finance` |
| 10 | 기타 | `etc` |

목록은 데이터 마이그레이션으로 넣고, 바꿀 때도 마이그레이션으로 바꾼다(원칙 IV). 화면에서 추가·수정하지 않는다.

## 16. 배포와 운영

- **Decision**: **리눅스 서버 한 대 + Docker Compose**. `caddy`(HTTPS 자동 발급, 정적 파일·이미지 제공) → `web`(Gunicorn + Django) → `db`(MySQL 8.4). 서버 cron이 7절 명령을 `docker compose exec`로 실행한다. 한국 리전 소형 VM(메모리 2GB 이상).
- **Rationale**: 한 서버에 모든 것이 있어 이해하기 쉽고, 개발 환경(같은 compose 파일)과 거의 같다.
- **Alternatives considered**: **PaaS(Render, Fly.io 등)**: MySQL·정기 작업·디스크를 각각 따로 구성해야 한다. **쿠버네티스**: 이 규모에 과하다.
- **메일**(review J-04): 운영은 SMTP 발송 서비스(예: Amazon SES), 발신 도메인에 SPF·DKIM을 설정한다. 개발은 **Mailpit**(가짜 메일함).
- **백업**(review J-01): 매일 `mysqldump`와 이미지 폴더를 다른 저장소로 복사하고 14일치를 보관한다. 한 달에 한 번 복구를 실제로 해 본다.
- **오류 기록**(review J-05): 사용자 화면에는 내부 정보를 보이지 않고(원칙 III), 운영자는 Gunicorn·Django 로그(표준 출력 → Docker 로그)와 500 오류 메일(`ADMINS`)로 본다. 로그에 비밀번호·토큰·세션 값을 남기지 않도록 요청 본문은 기록하지 않는다. 메일 인증·비밀번호 재설정 키는 allauth 주소 경로(`/accounts/confirm-email/{key}/`, `/accounts/password/reset/key/{key}/`)에 들어가므로, Caddy 접근 로그와 Gunicorn 접근 로그에서 이 두 경로의 키 부분을 `***`로 바꿔 기록한다(Caddy `log` 필터, Gunicorn `access_log_format`에서 경로 대신 가린 값). 키는 한 번 쓰면 끝나고 재설정 키는 1시간 뒤 만료된다(원칙 III).
- **비밀 값**: `.env`(저장소에 올리지 않음, `.env.example`만 커밋)로 넣는다(원칙 III).

## 17. 원칙을 코드에서 지키는 장치

| 원칙 | 장치 |
| --- | --- |
| I | 커밋·PR 제목에 요구사항 ID. 테스트의 `req` 표시 |
| II | `visibility.py` 한 곳. 화면 코드에 공개 범위 조건이 직접 나오면 실패하는 검사 테스트(`tests/unit/test_visibility_single_source.py`가 `apps/` 소스에서 `visibility=`·`hidden_at__isnull` 같은 문자열을 찾는다) |
| III | 템플릿 `safe` 필터는 정제된 본문 한 곳만. CSP 헤더(`default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'`)를 작은 미들웨어로 붙인다. 인라인 `<script>` 금지 |
| IV | 유일 키·생성 열·트랜잭션([data-model.md](./data-model.md) 9절). 마이그레이션만으로 구조 변경 |
| V | 13절 권한표 테스트, `uv run pytest` 하나 |
| VI | 의존성 목록은 plan.md에 이유와 함께. 그 밖의 라이브러리는 plan을 고친 뒤 들인다 |

---

## 초안(PR #2)에서 바뀐 것

| 항목 | 초안 | 지금 | 이유 |
| --- | --- | --- | --- |
| 요구사항 번호 | `FR-001` 등 | `AUTH-01` 등 통합본 ID | spec 2026-10-08 번호 변경 |
| 닉네임 | 1~20자, 중복 허용 | 2~20자, 중복 불가 | AUTH-01f |
| 태그 이름 | 1~30자 | 1~20자, 대소문자만 다르면 같은 태그 | TAG-01 |
| 글 주소 번호 | 서비스 전체 ID | 블로그마다 1부터, 지운 번호 다시 안 씀 | POST-01d |
| 카테고리 주소 | 이름 | 바뀌지 않는 번호 | CAT-02 |
| 발행일 | 처음 발행한 시각 | 처음 공개된 시각 | COM-P02 |
| 본문 요약 | 120자 | 서식 뺀 150자 | COM-P01 |
| 소셜 가입 | 자동 가입 | 동의·닉네임 확인 한 화면 | AUTH-01, AUTH-01e |
| 같은 이메일 | 소셜 → 이메일 방향만 | 모든 방향 | AUTH-01d |
| 검색 | ngram 전문 검색 | 부분 일치 LIKE | SRCH-01 "부분 일치" |
| 정렬 규칙 | `utf8mb4_0900_ai_ci` | `utf8mb4_0900_as_ci` | 대소문자만 무시(TAG-01) |
| 외부 링크 | 같은 창 | 새 창(`target="_blank"`) | POST-01b |
| CSP | django-csp | 작은 미들웨어 | 원칙 VI(새 라이브러리 줄이기) |
| 테스트 데이터 | factory_boy | pytest 픽스처 | 원칙 VI |
| 좁은 화면 사이드바 | `<dialog>` 서랍 메뉴(JS) | `<details>` 접기 | 원칙 VI(JS 없이 동작) |
