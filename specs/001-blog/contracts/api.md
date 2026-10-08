# Contract: JSON API

**Feature**: `001-blog` | **Date**: 2026-10-08 | **Plan**: [../plan.md](../plan.md)

새로고침 없이 처리하는 동작만 JSON으로 답한다. 화면 JS가 `fetch`로 부르는 내부 API이며 외부 공개 API가 아니다. 같은 동작은 JS 없이도 [pages.md](./pages.md)의 폼 주소로 할 수 있다(원칙 VI). 두 경로는 같은 서비스 함수를 불러 권한·검증이 똑같다.

## 공통 규칙

- **인증**: 로그인 세션 쿠키. 비회원이면 `401` + `{"login_url": "/accounts/login/?next=..."}`. JS가 그 주소로 보낸다(COM-02).
- **CSRF**: `GET`이 아닌 요청은 `X-CSRFToken` 헤더가 있어야 한다. 없으면 `403`(원칙 III).
- **본문**: `Content-Type: application/json`. 이미지 업로드만 `multipart/form-data`.
- **시각**: ISO 8601, 한국 시간(`+09:00`)으로 보낸다(COM-P07).
- **오류 형식**: 모든 `4xx`는 아래 모양이다. `field`는 입력 칸 이름이며, 화면이 그 칸 옆에 `message`를 보여 주고 입력은 지우지 않는다(COM-02a). 내부 정보는 담지 않는다.

  ```json
  { "error": { "code": "content_length", "message": "댓글은 1~1,000자로 써 주세요.", "field": "content" } }
  ```

- **상태 코드**: `200` 성공 / `201` 새로 만듦 / `400` 입력 오류 / `401` 로그인 필요 / `403` 권한 없음 / `404` 없음·볼 수 없음 / `413` 파일이 큼 / `429` 너무 잦은 요청.
- **볼 수 없는 대상**: 볼 수 없는 글에 대한 공감·댓글·조회는 `403`이 아니라 `404`다(원칙 II).
- **멱등성**(원칙 IV, COM-P06): 켜기·끄기는 `PUT`·`DELETE`라 같은 요청을 몇 번 보내도 결과가 같다. 새로 만드는 `POST`는 `client_token`(UUID)을 받고, 같은 토큰이면 처음 만든 결과를 `200`으로 다시 준다.
- **숫자**: 응답에 담는 공감 수·댓글 수·구독자 수는 응답 시점에 실제 행을 센 값이다(data-model 7절).

---

## 이미지

### `POST /api/images` · 이미지 업로드 (POST-05, COM-P03)

- 권한: 회원 / `multipart/form-data`, 칸 이름 `file`
- `201`:

  ```json
  { "id": 381, "url": "/media/images/2026/10/7c1e....jpg", "thumb_url": "/media/thumbs/2026/10/7c1e....jpg", "width": 1200, "height": 900 }
  ```

- `400 invalid_image`: Pillow가 jpg·png·gif·webp로 열지 못한 파일(확장자만 바꾼 파일 포함) / `413 image_too_large`: 10MB 초과
- 실패해도 에디터의 기존 본문·이미지는 그대로다(JS가 에디터를 건드리지 않음).

## 글쓰기 보조

### `GET /api/blogs/address-check?address={a}` · 블로그 주소 확인 (BLOG-01a)

- 권한: 회원
- `200`: `{ "available": false, "reason": "reserved" }`. `reason`은 `format` \| `length` \| `hyphen_edge` \| `reserved` \| `taken` 중 하나이며, 화면이 이유를 한국어로 보여 준다. 개설 `POST`에서도 서버가 같은 검사를 다시 한다.

### `PUT /api/drafts/current` · 임시저장 (POST-08, P2)

- 권한: 주인
- 본문: `{ "draft_id": null, "title": "...", "content": "<p>...</p>", "category_id": 3, "topic_id": 4, "tags": ["여행"], "visibility": "PUBLIC" }`
- `200`: `{ "draft_id": 12, "saved_at": "2026-10-08T13:05:00+09:00" }`. 제목·본문이 비어도 저장된다. 임시저장은 글 번호를 쓰지 않는다(POST-01d).

### `GET /api/tags?prefix={p}` · 내 블로그 태그 자동완성 (P2)

- 권한: 주인 / `200`: `{ "tags": ["여행", "여행기"] }` (최대 10개)

## 공감·구독

### `PUT /api/posts/{post_id}/like` · `DELETE /api/posts/{post_id}/like` (SOC-01)

- 권한: 회원. `post_id`는 내부 글 ID(화면이 `data-` 속성으로 가진다). 볼 수 없는 글은 `404`.
- `200`: `{ "liked": true, "like_count": 8 }` (`DELETE`면 `liked: false`). 이미 그 상태여도 `200`.
- `403 own_post`: 자기 글

### `PUT /api/blogs/{address}/subscription` · `DELETE ...` (SUB-01, SUB-03, P2)

- 권한: 회원. 삭제·이용 제한 블로그는 `404`.
- `200`: `{ "subscribed": true, "subscriber_count": 31 }`. P3에서 맞구독 상태 `"relation": "mutual"` 추가(SUB-05).
- `403 own_blog`: 자기 블로그

### `PUT /api/posts/{post_id}/save` · `DELETE ...` (SOC-03, P3)

- `200`: `{ "saved": true }`

## 댓글·방명록

### `GET /api/posts/{post_id}/comments?after={id}` · 댓글 더보기 (CMT-01)

- 권한: 모두(볼 수 있는 글만)
- `200`: `{ "comments": [ ... ], "next_after": 950 }`. 작성순 50개씩. 더 없으면 `next_after: null`.

### `POST /api/posts/{post_id}/comments` · 댓글 등록 (CMT-01)

- 권한: 회원 / 본문: `{ "content": "좋은 글이네요", "client_token": "4b0f..." }` (P3에서 `parent_id`, `is_secret` 추가)
- `201` (같은 `client_token`이면 `200`):

  ```json
  {
    "comment": {
      "id": 902,
      "author": { "nickname": "민주", "profile_image_url": "/media/thumbs/...jpg" },
      "content": "좋은 글이네요",
      "created_at": "2026-10-08T13:10:00+09:00",
      "edited": false,
      "can_edit": true,
      "can_delete": true
    },
    "comment_count": 5
  }
  ```

- `content`는 순수 텍스트로 돌려주고, JS는 `textContent`로만 넣는다(원칙 III).
- `400 content_length`: 앞뒤 공백 뺀 1~1,000자가 아님 / `429 too_fast`: 10초 안에 다시 등록(research 14절) / P3: `403 comments_closed`, `403 blocked`

### `PATCH /api/comments/{id}` · 댓글 수정 (CMT-03, P2)

- 권한: 작성자만. 블로그 주인도 남의 댓글은 `403`(CMT-02).
- 본문: `{ "content": "..." }` / `200`: `{ "comment": { ..., "edited": true } }`

### `DELETE /api/comments/{id}` · 댓글 삭제 (CMT-02)

- 권한: 작성자 또는 그 글의 블로그 주인. 이미 없으면 `404`.
- 화면은 보내기 전에 확인 창을 띄운다(COM-P04).
- `200`: `{ "comment_count": 4 }`. P3에서 답글이 있어 '삭제된 댓글'로 남으면 `"tombstone": true`.

### `POST /api/blogs/{address}/guestbook` · `PATCH /api/guestbook/{id}` · `DELETE /api/guestbook/{id}` (CMT-04, P2)

- 규칙과 응답 모양은 댓글과 같다. 삭제는 작성자 또는 블로그 주인.

## 목록 더 불러오기

### `GET /api/home/latest?cursor=` · `GET /api/topics/{slug}/posts?cursor=` · `GET /api/feed?cursor=`

- 권한: 모두(피드는 회원). 출처: HOME-01a, HOME-03(P2), SUB-02(P2)
- `cursor`는 앞 응답의 `next_cursor`(불투명 문자열, 안에는 `published_at`과 `id`). 첫 요청은 생략.
- `200`:

  ```json
  {
    "posts": [
      {
        "url": "/minju/12",
        "title": "가을 여행",
        "excerpt": "서식을 뺀 본문 앞 150자...",
        "thumb_url": "/media/thumbs/...jpg",
        "published_at": "2026-10-08T12:00:00+09:00",
        "blog": { "address": "minju", "name": "민주의 기록" }
      }
    ],
    "next_cursor": "MjAyNi0xMC0wOFQwMzowMDowMHwxMjA"
  }
  ```

- 더 없으면 `next_cursor: null`. 한 번에 20개(잠정, research 14절). 모든 목록은 `visible_posts(viewer)`에서 나온다(원칙 II).
- 커서가 망가졌으면 `400 invalid_cursor`.

## 관리자

서비스 관리 동작은 사유 입력이 필요한 폼 화면이라 [pages.md](./pages.md)의 `POST /admin/...`로만 처리한다. JSON API는 두지 않는다.
