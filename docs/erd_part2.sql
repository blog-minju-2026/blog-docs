-- ERD 파트 2 · 글·분류·검색 (민주)
-- MySQL 8.0 기준. 상세 설명은 ERD_파트2_글분류검색.md

-- ---------------------------------------------------------------
-- 다른 파트 엔티티 자리표시 (파트 1·3이 정의하면 지운다)
-- ---------------------------------------------------------------
CREATE TABLE members (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '회원 ID',
    PRIMARY KEY (id)
) COMMENT '회원 (파트 1)';

CREATE TABLE blogs (
    id BIGINT NOT NULL AUTO_INCREMENT COMMENT '블로그 ID',
    PRIMARY KEY (id)
) COMMENT '블로그 (파트 1)';

-- ---------------------------------------------------------------
-- 파트 2
-- ---------------------------------------------------------------
CREATE TABLE topics (
    id         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '주제 ID',
    name       VARCHAR(20) NOT NULL COMMENT '이름',
    sort_order INT         NOT NULL DEFAULT 0 COMMENT '정렬 순서',
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
    updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 일시',
    PRIMARY KEY (id),
    UNIQUE KEY uk_topics_name (name)
) COMMENT '주제';

CREATE TABLE categories (
    id         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '카테고리 ID',
    blog_id    BIGINT      NOT NULL COMMENT '블로그 ID',
    parent_id  BIGINT      NULL COMMENT '상위 카테고리 ID. NULL이면 최상위, 한 단계까지만(CAT-03)',
    name       VARCHAR(20) NOT NULL COMMENT '이름. 같은 상위 안에서 유일',
    sort_order INT         NOT NULL DEFAULT 0 COMMENT '정렬 순서(CAT-04)',
    is_private BOOLEAN     NOT NULL DEFAULT FALSE COMMENT '비공개 여부(CAT-05)',
    parent_key BIGINT AS (IFNULL(parent_id, 0)) STORED COMMENT '최상위 이름 중복 검사용 생성 열',
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
    updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 일시',
    PRIMARY KEY (id),
    UNIQUE KEY uk_categories_name (blog_id, parent_key, name),
    CONSTRAINT fk_categories_blog   FOREIGN KEY (blog_id)   REFERENCES blogs (id),
    CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE RESTRICT
) COMMENT '카테고리. 미분류·전체 글은 행으로 두지 않는다';

CREATE TABLE posts (
    id                 BIGINT       NOT NULL AUTO_INCREMENT COMMENT '글 ID. 플랫폼 전체에서 유일(7.5)',
    blog_id            BIGINT       NOT NULL COMMENT '블로그 ID',
    category_id        BIGINT       NULL COMMENT '카테고리 ID. NULL이면 미분류',
    topic_id           BIGINT       NULL COMMENT '주제 ID. NULL이면 주제 없음(7.7)',
    title              VARCHAR(100) NOT NULL DEFAULT '' COMMENT '제목. 발행 시 1~100자',
    content            LONGTEXT     NOT NULL COMMENT '본문 HTML(7.4)',
    thumbnail_url      VARCHAR(500) NULL COMMENT '대표 이미지 URL. NULL이면 본문 첫 이미지',
    visibility         VARCHAR(20)  NOT NULL DEFAULT 'PUBLIC' COMMENT '공개 범위 PUBLIC / PRIVATE / SUBSCRIBERS (7.8)',
    is_comment_allowed BOOLEAN      NOT NULL DEFAULT TRUE COMMENT '댓글 허용 여부(CMT-07)',
    view_count         INT          NOT NULL DEFAULT 0 COMMENT '조회 수',
    scheduled_at       DATETIME     NULL COMMENT '예약 일시(POST-13)',
    published_at       DATETIME     NULL COMMENT '발행 일시. 처음 공개된 시각, 수정해도 불변',
    status             VARCHAR(20)  NOT NULL DEFAULT 'DRAFT' COMMENT '글 상태 DRAFT / SCHEDULED / PUBLISHED',
    created_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
    updated_at         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 일시',
    hidden_at          DATETIME     NULL COMMENT '숨김 일시(ADMIN-03)',
    PRIMARY KEY (id),
    KEY idx_posts_blog_list     (blog_id, status, published_at),
    KEY idx_posts_category_list (category_id, published_at),
    KEY idx_posts_topic_list    (topic_id, published_at),
    FULLTEXT KEY ftx_posts_search (title, content) WITH PARSER ngram,
    CONSTRAINT fk_posts_blog     FOREIGN KEY (blog_id)     REFERENCES blogs (id),
    CONSTRAINT fk_posts_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
    CONSTRAINT fk_posts_topic    FOREIGN KEY (topic_id)    REFERENCES topics (id) ON DELETE SET NULL
) COMMENT '글';

CREATE TABLE tags (
    id         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '태그 ID',
    blog_id    BIGINT      NOT NULL COMMENT '블로그 ID',
    name       VARCHAR(30) NOT NULL COMMENT '이름. 블로그 안에서 유일',
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
    updated_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '수정 일시',
    PRIMARY KEY (id),
    UNIQUE KEY uk_tags_name (blog_id, name),
    CONSTRAINT fk_tags_blog FOREIGN KEY (blog_id) REFERENCES blogs (id)
) COMMENT '태그';

CREATE TABLE post_tags (
    post_id    BIGINT   NOT NULL COMMENT '글 ID',
    tag_id     BIGINT   NOT NULL COMMENT '태그 ID. 글당 최대 10개',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
    PRIMARY KEY (post_id, tag_id),
    KEY idx_post_tags_tag (tag_id),
    CONSTRAINT fk_post_tags_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_tags_tag  FOREIGN KEY (tag_id)  REFERENCES tags (id)  ON DELETE CASCADE
) COMMENT '글-태그';

CREATE TABLE images (
    id           BIGINT       NOT NULL AUTO_INCREMENT COMMENT '이미지 ID',
    member_id    BIGINT       NOT NULL COMMENT '회원 ID. 올린 회원',
    post_id      BIGINT       NULL COMMENT '글 ID. 글 저장 전이면 NULL',
    url          VARCHAR(500) NOT NULL COMMENT 'URL',
    content_type VARCHAR(20)  NOT NULL COMMENT '파일 유형 image/jpeg / image/png / image/gif / image/webp',
    file_size    INT          NOT NULL COMMENT '파일 크기(바이트)',
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시',
    PRIMARY KEY (id),
    CONSTRAINT fk_images_member FOREIGN KEY (member_id) REFERENCES members (id),
    CONSTRAINT fk_images_post   FOREIGN KEY (post_id)   REFERENCES posts (id) ON DELETE SET NULL
) COMMENT '이미지';

CREATE TABLE post_views (
    id         BIGINT      NOT NULL AUTO_INCREMENT COMMENT '조회 기록 ID',
    post_id    BIGINT      NOT NULL COMMENT '글 ID',
    member_id  BIGINT      NULL COMMENT '회원 ID. 비회원이면 NULL',
    viewer_key VARCHAR(64) NOT NULL COMMENT '방문자 키. 중복 조회 판단용',
    created_at DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '생성 일시(조회 시각)',
    PRIMARY KEY (id),
    KEY idx_post_views_time (created_at, post_id),
    CONSTRAINT fk_post_views_post   FOREIGN KEY (post_id)   REFERENCES posts (id) ON DELETE CASCADE,
    CONSTRAINT fk_post_views_member FOREIGN KEY (member_id) REFERENCES members (id) ON DELETE SET NULL
) COMMENT '조회 기록. 1시간 인기 글(7.6) 집계용';
