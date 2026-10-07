# Contract: 화면 주소 (HTML)

**Feature**: `001-blog` | **Date**: 2026-10-07 | **Plan**: [../plan.md](../plan.md)

서버가 HTML을 돌려주는 화면 주소 목록이다. 민주 개인 명세 6.2 화면 목록(SCR-xx)의 초안 주소를 Django 라우팅에 맞게 확정했다. JSON으로 답하는 주소는 [api.md](./api.md)에 있다.

## 공통 규칙

- **권한 표기**: `모두` / `회원`(로그인 필요) / `주인`(그 블로그 주인) / `관리자`(서비스 관리자).
- **로그인 필요한데 비회원**: `302 → /accounts/login/?next={원래 주소}`. 로그인 후 원래 주소로 돌아온다(FR-002, FR-111).
- **권한 없음**: `403` 화면. **없는 것·볼 수 없는 것**(삭제·비공개·숨김·이용 제한 블로그): `404` 화면. 둘 다 홈과 이전 화면으로 가는 링크가 있다(FR-111).
- **예상하지 못한 오류**: `500` 화면에 "잠시 후 다시 시도해 주세요"만. 내부 정보 없음(FR-112, 운영 `DEBUG=False`).
- **상태를 바꾸는 요청**은 모두 `POST`이고 CSRF 토큰이 필요하다(FR-116). `GET`으로는 아무것도 바뀌지 않는다(조회수 기록 제외).
- **목록 페이지**: `?page=N`(1부터, 10개씩). 마지막을 넘으면 빈 목록 `200`(FR-113).
- **한글 경로**: 카테고리·태그 이름은 퍼센트 인코딩해 쓴다. Django가 디코딩하므로 `/{blog}/tag/여행`이 그대로 열린다.
- `{blog}` = 블로그 주소(`[a-z0-9-]{4,32}`), `{id}` = 글 번호(숫자).

## 서비스 화면

| 화면 | 메서드·주소 | 권한 | 응답 | 출처 |
| --- | --- | --- | --- | --- |
| SCR-01 홈 | `GET /` | 모두 | 인기 글(P2), 인기 블로거(P3), 주제 탭(P2), 최신 글 첫 20개 | FR-080~085 |
| SCR-02 통합 검색 | `GET /search?q=&type=posts\|blogs&sort=relevance\|recent&page=` | 모두 | 글·블로그 탭과 개수. `q`가 공백뿐이면 검색하지 않고 안내 | FR-071 (P2) |
| SCR-03 주제별 글 | `GET /topic/{slug}` | 모두 | 그 주제 공개 글 최신순, 더 불러오기. 없는 slug는 404 | FR-083 (P2) |
| SCR-04 랭킹 전체보기 | `GET /ranking?tab=posts\|bloggers` | 모두 | 홈과 같은 스냅숏 | FR-085 (P3) |
| 구독 피드 | `GET /feed` | 회원 | 구독 블로그 새 글, 더 불러오기. 구독 없으면 안내 + 홈 링크 | FR-061 (P2) |

## 회원·인증 (django-allauth)

| 화면 | 메서드·주소 | 권한 | 비고 |
| --- | --- | --- | --- |
| SCR-05 로그인 | `GET, POST /accounts/login/` | 비회원 | 이메일 로그인 폼 + 카카오·구글·네이버 버튼. 실패 문구는 하나 |
| 이메일 가입 | `GET, POST /accounts/signup/` | 비회원 | 이메일·비밀번호(8자 이상)·닉네임 → 인증 메일 발송 |
| 메일 인증 | `GET /accounts/confirm-email/{key}/` | 모두 | 인증 완료 후 로그인 |
| 비밀번호 재설정 요청 | `GET, POST /accounts/password/reset/` | 모두 | 가입 여부와 관계없이 같은 안내(계정 존재 노출 방지) |
| 비밀번호 재설정 | `GET, POST /accounts/password/reset/key/{key}/` | 모두 | 1시간, 한 번만 |
| 소셜 로그인 시작 | `POST /accounts/{kakao\|google\|naver}/login/` | 비회원 | 제공사로 이동 |
| 소셜 콜백 | `GET /accounts/{provider}/login/callback/` | 모두 | 첫 로그인이면 자동 가입. 같은 이메일 계정이 있으면 가입하지 않고 로그인 화면에 안내(FR-001d). 취소·실패면 로그인 화면에 이유 |
| 로그아웃 | `POST /accounts/logout/` | 회원 | 홈으로 |

## 내 정보 (`/me`)

| 화면 | 메서드·주소 | 권한 | 출처 |
| --- | --- | --- | --- |
| SCR-11 내 정보 | `GET, POST /me` | 회원 | 닉네임·프로필 이미지(FR-007, P2) |
| 탈퇴 | `GET, POST /me/withdraw` | 회원 | 확인 화면 후 처리(FR-008, P3) |
| SCR-12 구독 목록 | `GET /me/subscriptions` | 회원 | 구독한 블로그, 여기서 해제(FR-060, P2) |
| 저장한 글 | `GET /me/saved` | 회원 | P3 |
| 알림 | `GET /me/notifications` | 회원 | P3 |

## 블로그 개설·관리 (`/blog/new`, `/manage`)

`/manage/*`는 로그인한 회원의 **자기 블로그**만 다룬다. 주소에 블로그를 넣지 않으므로 남의 블로그 관리 화면이라는 것이 생기지 않는다. 블로그가 없는 회원은 `/blog/new`로 보낸다(FR-006).

| 화면 | 메서드·주소 | 권한 | 출처 |
| --- | --- | --- | --- |
| SCR-13 블로그 개설 | `GET, POST /blog/new` | 회원(블로그 없음) | "주소는 바꿀 수 없음" 안내. 이미 있으면 `/{blog}`로 보내고 막음(FR-010~012) |
| SCR-14 새 글 | `GET /manage/write` | 주인 | 빈 에디터. 임시저장이 있으면 이어 쓸지 묻기(P2) |
| SCR-14 발행 | `POST /manage/write` | 주인 | 성공 `302 → /{blog}/{id}`. 실패면 같은 화면에 첫 번째 오류 + 입력 유지(FR-021, FR-112) |
| SCR-14 글 수정 | `GET, POST /manage/write/{id}` | 주인 | 남의 글이면 404 |
| 글 삭제 | `POST /manage/posts/{id}/delete` | 주인 | 확인 후. `302 → /manage/posts`(FR-026) |
| SCR-15 글 관리 | `GET /manage/posts?status=` | 주인 | 상태별·숨김 사유 표시(FR-090, P2) |
| SCR-16 댓글 관리 | `GET /manage/comments` | 주인 | 댓글·방명록 최신순(FR-091, P2) |
| SCR-17 카테고리 관리 | `GET, POST /manage/categories` | 주인 | 추가·이름 변경·삭제(FR-040), 하위·순서(P2) |
| 태그 관리 | `GET, POST /manage/tags` | 주인 | P3 |
| SCR-18 블로그 설정 | `GET, POST /manage/settings` | 주인 | 이름·소개·프로필(FR-014), 삭제(P3) |
| 방문 통계 | `GET /manage/stats` | 주인 | P3 |

## 블로그 화면 (`/{blog}`)

모든 화면에 같은 사이드바(블로그 이름·프로필·카테고리와 글 수)가 붙는다(FR-016). 삭제·이용 제한 블로그는 모두 404.

| 화면 | 메서드·주소 | 권한 | 출처 |
| --- | --- | --- | --- |
| SCR-06 블로그 메인 | `GET /{blog}?page=` | 모두 | FR-015 |
| SCR-09 글 상세 | `GET /{blog}/{id}` | 모두(볼 수 있는 글만) | 글이 그 블로그 소속이 아니면 404. 조회 기록(FR-034). 이전·다음 글(P2) |
| SCR-07 카테고리 | `GET /{blog}/category/{name}?page=` | 모두 | 하위: `/{blog}/category/{parent}/{child}` |
| SCR-08 태그 | `GET /{blog}/tag/{name}?page=` | 모두 | FR-046 |
| 미분류 글 | `GET /{blog}/uncategorized?page=` | 모두 | 카테고리 이름과 겹치지 않게 별도 경로 |
| 태그 모아 보기 | `GET /{blog}/tags` | 모두 | FR-047 (P2) |
| 블로그 내 검색 | `GET /{blog}/search?q=&page=` | 모두 | 제목·본문·태그(FR-070) |
| SCR-10 방명록 | `GET /{blog}/guestbook?page=` | 모두 | 작성은 api.md(P2) |
| 댓글 등록(JS 없을 때) | `POST /{blog}/{id}/comments` | 회원 | 성공 `302 → /{blog}/{id}#comment-{cid}` |

## 서비스 관리 (`/admin`)

Django 기본 관리 도구는 운영자 전용으로 `/django-admin/`에 따로 둔다. 서비스 관리자 화면은 사유 입력·기록이 필요하므로 직접 만든다.

| 화면 | 메서드·주소 | 권한 | 출처 |
| --- | --- | --- | --- |
| SCR-19 관리 홈 | `GET /admin` | 관리자 | 회원·글·신고 바로가기. 대시보드 수치는 P3 |
| 회원 목록·이용 제한 | `GET /admin/users`, `POST /admin/users/{id}/sanction`, `POST /admin/users/{id}/release` | 관리자 | FR-102 (P2). 대상이 관리자면 403 |
| 글 숨김 | `POST /admin/posts/{id}/hide`, `POST /admin/posts/{id}/unhide` | 관리자 | 사유 필수(FR-103, P2) |
| 댓글 숨김 | `POST /admin/comments/{id}/hide`, `POST /admin/comments/{id}/unhide` | 관리자 | FR-103 (P2) |
| 신고·공지·이력 | `/admin/reports`, `/admin/notices`, `/admin/logs` | 관리자 | P3 |

## 블로그 주소 예약어

`/{blog}`가 위 서비스 경로와 겹치지 않도록 다음은 블로그 주소로 쓸 수 없다(FR-011). 서비스 경로를 새로 만들면 여기에도 더한다.

`about accounts admin api blog django-admin feed help login logout manage me media notice ranking search signup static topic www`
