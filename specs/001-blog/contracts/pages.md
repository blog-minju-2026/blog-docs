# Contract: 화면 주소 (HTML)

**Feature**: `001-blog` | **Date**: 2026-10-08 | **Plan**: [../plan.md](../plan.md)

서버가 HTML을 돌려주는 화면 주소 목록이다. JSON으로 답하는 주소는 [api.md](./api.md)에 있다. 각 줄의 '출처'는 spec 요구사항 ID다(원칙 I).

## 공통 규칙

- **권한 표기**: `모두` / `회원`(로그인 필요) / `주인`(그 블로그 주인) / `관리자`(서비스 관리자). 권한은 서버가 요청마다 검사한다(원칙 II, COM-01).
- **로그인이 필요한데 비회원**: `302 → /accounts/login/?next={원래 주소}`. 로그인 후 원래 주소로 돌아온다(AUTH-01h, COM-02). `next`는 같은 사이트 주소만 받는다.
- **권한 없음**: `403` 화면. **없는 것·볼 수 없는 것**(삭제·비공개·숨김·임시저장·이용 제한 블로그, 남의 블로그 글 번호): `404` 화면. 둘 다 홈과 이전 화면으로 가는 링크가 있다(COM-02).
- **예상하지 못한 오류**: `500` 화면에 "잠시 후 다시 시도해 주세요"만 보인다. 내부 정보 없음(COM-02a, 원칙 III).
- **상태를 바꾸는 요청**은 모두 `POST`이고 CSRF 토큰이 필요하다. `GET`으로는 아무것도 바뀌지 않는다. 조회 기록만 예외다(원칙 III).
- **입력 오류**: 같은 화면을 `200`으로 다시 그리고, 틀린 칸 옆에 이유를 보여 주며, 입력한 내용을 지우지 않는다(COM-02a).
- **목록 페이지**: `?page=N`(1부터, 10개씩). 마지막을 넘으면 빈 목록 `200`(COM-P01). `N`이 숫자가 아니면 1페이지.
- **더 불러오기 목록**: `?cursor=...`. JS가 있으면 [api.md](./api.md)로 이어 붙이고, 없으면 같은 커서의 "다음" 링크가 된다.
- **한글 경로**: 태그 이름은 퍼센트 인코딩한다. `/{blog}/tag/여행`이 그대로 열린다(spec Edge Cases).
- `{blog}` = 블로그 주소(`[a-z0-9-]{4,32}`), `{no}` = 블로그 안 글 번호, `{id}` = 카테고리 번호.

## 서비스 화면

| 화면 | 메서드·주소 | 권한 | 응답 | 출처 |
| --- | --- | --- | --- | --- |
| 홈 | `GET /` | 모두 | 랜딩 없이 최신 글 첫 20개. P2부터 인기 글·주제 영역, P3부터 인기 블로거 | HOME-01, HOME-01a, HOME-02, HOME-03, HOME-04 |
| 통합 검색 | `GET /search?q=&type=posts\|blogs&sort=relevance\|recent&page=` | 모두 | 글·블로그 탭과 각 개수. 글마다 소속 블로그. `q`가 공백뿐이면 검색하지 않고 안내. 결과가 없으면 인기 글 추천 | SRCH-02 (P2) |
| 주제별 글 | `GET /topic/{slug}?cursor=` | 모두 | 그 주제의 볼 수 있는 글 최신순. 없는 slug는 404 | HOME-03 (P2) |
| 구독 피드 | `GET /feed?cursor=` | 회원 | 구독 블로그의 볼 수 있는 글 최신순. 구독이 없으면 안내 + 홈 링크 | SUB-02 (P2) |
| 이용약관 | `GET /terms` | 모두 | 모든 화면 푸터에서 링크 | AUTH-01e |
| 개인정보처리방침 | `GET /privacy` | 모두 | 모든 화면 푸터에서 링크 | AUTH-01e |
| 랭킹 전체보기 | `GET /ranking?tab=posts\|bloggers` | 모두 | 홈과 같은 스냅숏 | HOME-05 (P3) |

## 회원·인증 (django-allauth)

| 화면 | 메서드·주소 | 권한 | 동작 | 출처 |
| --- | --- | --- | --- | --- |
| 로그인 | `GET, POST /accounts/login/` | 비회원 | 이메일 로그인 폼 + 카카오·구글·네이버 버튼. 실패 문구는 하나. 연속 실패 시 잠시 막고 안내. 이용 제한 회원은 사유·기한 안내. 미인증 이메일은 인증 안내 + 다시 보내기 | AUTH-01b, AUTH-01g, ADMIN-02 |
| 이메일 가입 | `GET, POST /accounts/signup/` | 비회원 | 이메일·비밀번호(8자 이상)·닉네임(2~20자, 중복 불가) + 필수 동의 2개 + 만 14세 이상 확인 → 인증 메일 발송. 이미 가입된 이메일(어느 방식이든)은 가입된 방식으로 안내 | AUTH-01a, AUTH-01d, AUTH-01e, AUTH-01f |
| 메일 인증 | `GET, POST /accounts/confirm-email/{key}/` | 모두 | 인증 완료 → 로그인 화면 | AUTH-01a |
| 비밀번호 재설정 요청 | `GET, POST /accounts/password/reset/` | 모두 | 가입 여부와 관계없이 같은 안내 | AUTH-01c |
| 비밀번호 재설정 | `GET, POST /accounts/password/reset/key/{key}/` | 모두 | 1시간, 한 번만. 쓴 링크는 "쓸 수 없는 링크" 안내 | AUTH-01c |
| 소셜 로그인 시작 | `POST /accounts/{kakao\|google\|naver}/login/` | 비회원 | 제공사로 이동 | AUTH-01 |
| 소셜 콜백 | `GET /accounts/{provider}/login/callback/` | 모두 | 이미 가입한 소셜 계정이면 로그인. 처음이면 소셜 가입 화면으로. 같은 이메일이 다른 방식으로 가입돼 있으면 가입하지 않고 로그인 화면에 안내. 취소·실패면 로그인 화면에 이유 | AUTH-01, AUTH-01d, AUTH-01h |
| 소셜 가입(동의·닉네임) | `GET, POST /accounts/3rdparty/signup/` | 비회원(소셜 인증 직후) | 한 화면에서 필수 동의 2개 + 만 14세 이상 확인 + 닉네임(제공사 닉네임으로 미리 채움) → 가입 후 원래 화면 | AUTH-01, AUTH-01e, AUTH-01f |
| 로그아웃 | `POST /accounts/logout/` | 회원 | 홈으로 | AUTH-02 |

allauth 기본 화면 중 이 표에 없는 것(이메일 주소 추가·변경, 소셜 계정 연결 관리)은 URL에서 뺀다. 계정 연결 기능은 두지 않는다(AUTH-01d).

## 내 정보 (`/me`)

| 화면 | 메서드·주소 | 권한 | 출처 |
| --- | --- | --- | --- |
| 내 정보 | `GET, POST /me` | 회원 | 닉네임·회원 프로필 이미지 수정(AUTH-05, P2) |
| 구독 목록 | `GET /me/subscriptions`, `POST /me/subscriptions/{address}/delete` | 회원 | 구독한 블로그, 여기서 해제(SUB-01, P2) |
| 탈퇴 | `GET, POST /me/withdraw` | 회원 | 확인 화면 후 처리(AUTH-06, COM-P04, P3) |
| 저장한 글 | `GET /me/saved` | 회원 | SOC-03 (P3) |
| 알림 | `GET /me/notifications` | 회원 | SUB-04 (P3) |

## 블로그 개설·관리 (`/blog/new`, `/manage`)

`/manage/*`는 로그인한 회원의 **자기 블로그**만 다룬다. 블로그가 없는 회원이 들어오면 `/blog/new`로 보낸다(AUTH-04).

| 화면 | 메서드·주소 | 권한 | 동작 | 출처 |
| --- | --- | --- | --- | --- |
| 블로그 개설 | `GET, POST /blog/new` | 회원(살아 있는 블로그 없음) | 주소·이름·소개. "주소는 개설 후 바꿀 수 없다" 안내. 이미 있으면 `/{blog}`로 보내고 막는다. 성공 `302 → /manage/write` | BLOG-01, BLOG-01a, BLOG-01b, BLOG-01d |
| 새 글 | `GET /manage/write` | 주인 | 빈 에디터. 숨은 `client_token`. P2: 임시저장이 있으면 이어 쓸지 묻기 | POST-01, POST-08 |
| 발행 | `POST /manage/write` | 주인 | 성공 `302 → /{blog}/{no}`. 같은 `client_token`이면 처음 글로 `302`. 실패면 같은 화면에 첫 번째 오류 + 입력 유지 | POST-01, POST-01a, POST-01c, COM-P06 |
| 글 수정 | `GET, POST /manage/write/{no}` | 주인 | 남의 글·없는 번호는 404. 성공 `302 → /{blog}/{no}` | POST-02 |
| 글 삭제 | `POST /manage/posts/{no}/delete` | 주인 | 확인 후(화면의 확인 창 + 서버는 POST만). `302 → /{blog}` 또는 `/manage/posts` | POST-03, COM-P04 |
| 글 관리 | `GET /manage/posts?status=public\|private\|draft\|hidden&page=` | 주인 | 상태별 구분, 숨김 사유. 공개 범위 바꾸기 `POST /manage/posts/{no}/visibility` | MNG-01 (P2) |
| 댓글 관리 | `GET /manage/comments?page=` | 주인 | 댓글·방명록 최신순, 어느 글인지 표시, 삭제 | MNG-02 (P2) |
| 카테고리 관리 | `GET /manage/categories`, `POST /manage/categories`, `POST /manage/categories/{id}`, `POST /manage/categories/{id}/delete` | 주인 | 추가·이름 변경·삭제(글은 미분류로). P2: 하위·순서 | CAT-01, CAT-03, CAT-04 |
| 블로그 설정 | `GET, POST /manage/settings` | 주인 | 이름·소개·블로그 프로필 이미지. 주소는 보여 주기만 | BLOG-02 |
| 태그 관리 | `GET, POST /manage/tags` | 주인 | TAG-04 (P3) |
| 방문 통계 | `GET /manage/stats` | 주인 | MNG-03 (P3) |
| 블로그 삭제 | `GET, POST /manage/settings/delete` | 주인 | BLOG-07 (P3) |

## 블로그 화면 (`/{blog}`)

모든 화면에 같은 사이드바(블로그 이름·프로필 → 블로그 메인, '전체 글' 맨 위·'미분류' 맨 아래인 카테고리 목록과 볼 수 있는 글 수)가 붙는다(BLOG-04). 좁은 화면에서는 본문 아래 접기(`<details>`)로 둔다. 삭제·이용 제한 블로그는 모든 주소가 404다(ADMIN-02).

| 화면 | 메서드·주소 | 권한 | 동작 | 출처 |
| --- | --- | --- | --- | --- |
| 블로그 메인 | `GET /{blog}?page=` | 모두 | 볼 수 있는 글 최신순, 제목·발행일·카테고리·요약. 비면 빈 상태 | BLOG-03, COM-P01 |
| 글 상세 | `GET /{blog}/{no}` | 모두(볼 수 있는 글만) | 그 블로그 글이 아니면 404. 주인에게 수정·삭제. P2: 조회 기록, 이전·다음 글, 주소 복사 | POST-04, POST-04a, POST-09, POST-10, SOC-02 |
| 카테고리 글 | `GET /{blog}/category/{id}?page=` | 모두 | 그 카테고리(상위면 하위 포함) 글. 다른 블로그 카테고리 번호면 404 | CAT-02, CAT-03 |
| 미분류 글 | `GET /{blog}/uncategorized?page=` | 모두 | 미분류 글 | CAT-01 |
| 태그 글 | `GET /{blog}/tag/{name}?page=` | 모두 | 그 태그 글. 없는 태그는 404 | TAG-02 |
| 태그 모아 보기 | `GET /{blog}/tags` | 모두 | 볼 수 있는 글이 있는 태그만 | TAG-03 (P2) |
| 블로그 내 검색 | `GET /{blog}/search?q=&page=` | 모두 | 제목·본문·태그 부분 일치, 결과가 없으면 검색어를 남긴 채 안내. 공백뿐이면 검색하지 않음 | SRCH-01 |
| 방명록 | `GET /{blog}/guestbook?page=` | 모두 | 최신순. 작성·삭제는 api.md(JS 없으면 아래 폼) | CMT-04 (P2) |
| 댓글 등록(JS 없을 때) | `POST /{blog}/{no}/comments` | 회원 | 성공 `302 → /{blog}/{no}#comment-{id}` | CMT-01 |
| 댓글 삭제(JS 없을 때) | `POST /{blog}/{no}/comments/{id}/delete` | 작성자·주인 | 확인 후 | CMT-02 |
| 공감(JS 없을 때) | `POST /{blog}/{no}/like`, `POST /{blog}/{no}/unlike` | 회원 | `302 → /{blog}/{no}` | SOC-01 |
| 구독(JS 없을 때) | `POST /{blog}/subscribe`, `POST /{blog}/unsubscribe` | 회원 | `302 → /{blog}` | SUB-01 (P2) |
| 방명록 등록(JS 없을 때) | `POST /{blog}/guestbook` | 회원 | `302 → /{blog}/guestbook` | CMT-04 (P2) |

## 서비스 관리 (`/admin`)

Django 기본 관리 도구는 운영자 전용으로 `/django-admin/`에 따로 둔다(서비스 관리자 화면이 아님). 서비스 관리 화면은 사유 입력·기록이 필요하므로 직접 만든다. 어떤 관리 화면에도 남의 글·댓글 내용을 고치는 기능은 없다(원칙 II, ADMIN-01a).

| 화면 | 메서드·주소 | 권한 | 동작 | 출처 |
| --- | --- | --- | --- | --- |
| 관리 홈 | `GET /admin` | 관리자 | 회원·글 검색 바로가기. 대시보드 수치는 P3 | ADMIN-01, ADMIN-06 |
| 회원 검색·이용 제한 | `GET /admin/users?q=`, `POST /admin/users/{id}/sanction`, `POST /admin/users/{id}/release` | 관리자 | 기간(날짜·영구)·사유 필수. 대상이 관리자면 403 | ADMIN-02 (P2) |
| 글 검색·숨김 | `GET /admin/posts?q=`, `GET /admin/posts/{id}`, `POST /admin/posts/{id}/hide`, `POST /admin/posts/{id}/unhide` | 관리자 | 대상 글 본문은 여기서만 볼 수 있다(권한표 '제재에 필요한 범위'). 사유 필수 | ADMIN-03 (P2) |
| 댓글·방명록 숨김 | `POST /admin/comments/{id}/hide` · `unhide`, `POST /admin/guestbook/{id}/hide` · `unhide` | 관리자 | 사유 필수 | ADMIN-03 (P2) |
| 신고·블로그 제한·공지·이력 | `/admin/reports`, `/admin/blogs/{id}/restrict`, `/admin/notices`, `/admin/logs` | 관리자 | ADMIN-04, ADMIN-05, ADMIN-06 (P3) |

## 블로그 주소 예약어

`/{blog}`가 서비스 경로와 겹치지 않도록 다음은 블로그 주소로 쓸 수 없다(BLOG-01a). 서비스 경로를 새로 만들면 여기와 `apps/blogs/reserved.py`에 함께 더한다. 테스트가 URL 설정과 이 목록이 맞는지 확인한다([plan.md](../plan.md) Structure Decision).

`about accounts admin api blog django-admin feed help login logout manage me media notice notices privacy ranking search signup static terms topic www`

4자 미만 단어(`api`, `me`, `www` 등)는 길이 규칙(4~32자)으로도 막히지만, 규칙이 바뀌어도 안전하도록 목록에 둔다.
