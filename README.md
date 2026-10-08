# blog-docs

한채 블로그 플랫폼(티스토리형 블로그)의 기획·명세 문서 저장소입니다.
[GitHub Spec Kit](https://github.com/github/spec-kit)의 흐름(constitution → specify → clarify → plan → tasks → implement)을 따릅니다.

## 구조

```
blog-docs/
├── .specify/
│   └── memory/
│       └── constitution.md      # 프로젝트 원칙 (모든 단계가 지킬 기준)
├── specs/
│   └── 001-blog/
│       ├── spec.md                  # Spec Kit 기능 명세 (무엇을, 왜)
│       └── checklists/
│           └── requirements.md      # 명세 품질 체크리스트
└── docs/                            # 원본 문서 (수정하지 않고 참고용으로 보관)
    └── 1팀_블로그_통합_기능명세서.md  # 팀 통합본 v0.2, spec.md의 기준 문서
```

## 다음 단계

1. `/speckit.constitution`: 프로젝트 원칙 v1.0.0 작성 (2026-10-08)
2. `/speckit.clarify`: 미결정 사항 모두 정리 완료 (2026-10-07)
3. `/speckit.plan`: 기술 스택, 화면, 데이터 모델 (다음 단계)
4. `/speckit.tasks` → `/speckit.implement`
