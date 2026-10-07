# blog-docs

한채 블로그 플랫폼(티스토리형 블로그)의 기획·명세 문서 저장소입니다.
[GitHub Spec Kit](https://github.com/github/spec-kit)의 흐름(constitution → specify → clarify → plan → tasks → implement)을 따릅니다.

## 구조

```
blog-docs/
├── specs/
│   └── 001-blog/
│       ├── spec.md                  # Spec Kit 기능 명세 (무엇을, 왜)
│       └── checklists/
│           └── requirements.md      # 명세 품질 체크리스트
└── docs/                            # 원본 문서 (수정하지 않고 참고용으로 보관)
    ├── 1팀_블로그_통합_기능명세서.md  # 팀 통합본 v0.2, spec.md의 기준 문서
    ├── 기능명세서.md                  # 한채 개인 명세 v0.6
    ├── ERD.md                       # 팀 ERD 기본안
    ├── ERD_파트2_글분류검색.md        # 글·분류·검색 파트 ERD
    └── erd_part2.sql                # 파트 2 스키마 초안
```

## 다음 단계

1. `/speckit.clarify`: 미결정 사항 모두 정리 완료 (2026-10-07)
2. `/speckit.plan`: 기술 스택, 화면, 데이터 모델(ERD를 `data-model.md`로 정리)
3. `/speckit.tasks` → `/speckit.implement`
