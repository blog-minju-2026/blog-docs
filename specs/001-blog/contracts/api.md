# Contract: JSON API

**Feature**: `001-blog` | **Date**: 2026-10-07 | **Plan**: [../plan.md](../plan.md)

화면을 새로고침하지 않고 처리하는 동작만 JSON으로 답한다. 화면 JS가 `fetch`로 부르는 내부 API이며, 외부 공개 API가 아니다.

## 공통 규칙

- **인증**: 로그인 세션 쿠키. 비회원이면 `401` + `{"login_url": "/accounts/login/?next=..."}` → JS가 그 주소로 보낸다(FR-111).
- **CSRF**: `GET`이 아닌 요청은 `X-CSRFToken` 헤더 필수. 없으면 `403`(FR-116).
- **본문**: `Content-Type: application/json`(이미지 업로드만 `multipart/form-data`).
- **오류 형식**: 모든 `4xx`는 아래 모양이다. `field`는 입력 칸 이름이며 화면이 그 칸 옆에 `message`를 보여 준다(FR-112).

  ```json
  { "error": { "code": "title_required", "message": "제목을 입력해 주세요.", "field": "title" } }
  ```

- **상태 코드**: `200` 성공 / `201` 새로 만듦 / `204` 내용 없음 / `400` 입력 오류 / `401` 로그인 필요 / `403` 권한 없음 / `404` 없음·볼 수 없음 / `413` 파일이 큼 / `429` 너무 잦은 요청.
- **멱등성**: 켜기·끄기는 `PUT`·`DELETE`이고 같은 요청을 몇 번 보내도 결과가 같다. 새로 만드는 `POST`는 `client_token`(UUID)을 받아 같은 토큰이면 처음 결과를 `200`으로 돌려준다(FR-117).

---

## 이미지

### `POST /api/images` — 이미지 업로드 (FR-029, FR-114)

- 권한: 회원 / `multipart/form-data`, 필드 `file`
- `201`:

  ```json
  { "id": 381, "url": "/media/images/2026/10/7c1e....jpg", "width": 1200, "height": 900 }
  ```

- `400 invalid_image`: jpg·png·gif·webp가 아니거나 열 수 없는 파일 / `413 image_too_large`: 10MB 초과

## 글 쓰기 보조

### `PUT /api/drafts/current` — 임시저장 (FR-033, P2)

- 권한: 주인 / 본문: `{ "draft_id": 12 | null, "title": "...", "content": "<p>...</p>", "category_id": 3, "topic_id": 4, "tags": ["여행"], "visibility": "PUBLIC" }`
- `200`: `{ "draft_id": 12, "saved_at": "2026-10-07T13:05:00+09:00" }`. 제목·본문이 비어도 저장된다.

### `GET /api/blogs/address-check?address={a}` — 블로그 주소 확인 (FR-011)

- 권한: 회원
- `200`: `{ "available": false, "reason": "reserved" }`. `reason`은 `format` \| `length` \| `hyphen_edge` \| `reserved` \| `taken` 중 하나.

### `GET /api/tags?prefix={p}` — 내 블로그 태그 자동완성 (P2)

- 권한: 주인 / `200`: `{ "tags": ["여행", "여행기"] }` (최대 10개)

## 공감·구독·저장

### `PUT /api/posts/{id}/like` · `DELETE /api/posts/{id}/like` (FR-057)

- 권한: 회원. 볼 수 없는 글은 `404`.
- `200`: `{ "liked": true, "like_count": 8 }` (`DELETE`면 `liked: false`). 이미 그 상태여도 `200`.
- `403 own_post`: 자기 글

### `PUT /api/blogs/{address}/subscription` · `DELETE ...` (FR-060, P2)

- 권한: 회원
- `200`: `{ "subscribed": true, "subscriber_count": 31 }`. P3에서 `"mutual": true` 추가.
- `403 own_blog`: 자기 블로그

### `PUT /api/posts/{id}/save` · `DELETE ...` (FR-059, P3)

- `200`: `{ "saved": true }`

## 댓글·방명록

### `POST /api/posts/{id}/comments` — 댓글 등록 (FR-050)

- 권한: 회원 / 본문: `{ "content": "좋은 글이네요", "client_token": "4b0f...", "parent_id": null, "is_secret": false }` (`parent_id`·`is_secret`은 P3)
- `201` (같은 `client_token`이면 `200`):

  ```json
  {
    "comment": { "id": 902, "author": { "nickname": "민주", "blog_address": "minju" },
                 "content": "좋은 글이네요", "created_at": "2026-10-07T13:10:00+09:00",
                 "can_edit": true, "can_delete": true },
    "comment_count": 5
  }
  ```

- `400 content_length`: 1~1,000자가 아님 / `403 comments_closed`: 댓글 막힌 글(P3)

### `PATCH /api/comments/{id}` — 댓글 수정 (FR-052, P2)

- 권한: 작성자만. 블로그 주인도 남의 댓글은 `403`.
- 본문: `{ "content": "..." }` / `200`: `{ "comment": {...} }`

### `DELETE /api/comments/{id}` — 댓글 삭제 (FR-051)

- 권한: 작성자 또는 그 블로그 주인. 이미 없으면 `404`.
- `200`: `{ "comment_count": 4, "tombstone": false }`. 답글이 있어 '삭제된 댓글'로 남으면 `tombstone: true`(P3).

### `POST /api/blogs/{address}/guestbook` · `DELETE /api/guestbook/{id}` (FR-053, P2)

- 규칙과 응답 모양은 댓글과 같다.

## 목록 더 불러오기

### `GET /api/home/latest?cursor={c}` · `GET /api/topics/{slug}/posts?cursor={c}` · `GET /api/feed?cursor={c}`

- 권한: 모두(피드는 회원)
- `cursor`는 앞 응답의 `next_cursor`(불투명 문자열, 내부적으로 `published_at`과 `id`). 첫 요청은 생략.
- `200`:

  ```json
  {
    "posts": [
      { "id": 120, "url": "/minju/120", "title": "가을 여행", "excerpt": "본문 앞 120자...",
        "thumbnail_url": "/media/images/...jpg", "published_at": "2026-10-07T12:00:00+09:00",
        "blog": { "address": "minju", "name": "민주의 기록" } }
    ],
    "next_cursor": "MjAyNi0xMC0wN1QwMzowMDowMHwxMjA" 
  }
  ```

- 더 없으면 `next_cursor: null`. 한 번에 20개(잠정).

## 관리자

서비스 관리 동작은 사유 입력이 필요한 폼 화면이라 [pages.md](./pages.md)의 `POST /admin/...`로 처리한다. JSON API는 두지 않는다.
