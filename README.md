# blog-docs

한채 블로그 플랫폼(티스토리형 블로그)의 기획·명세 문서 저장소입니다.
[GitHub Spec Kit](https://github.com/github/spec-kit)의 흐름(constitution → specify → clarify → plan → tasks → implement)을 따릅니다.

## 구조

```
blog-docs/
├── .claude/skills/speckit-*/        # Claude Code용 Spec Kit 명령 (/speckit-tasks 등)
├── .specify/
│   ├── memory/
│   │   └── constitution.md      # 프로젝트 원칙 (모든 단계가 지킬 기준)
│   ├── scripts/bash/            # Spec Kit 명령이 부르는 스크립트
│   └── templates/               # spec·plan·tasks 틀
├── specs/
│   └── 001-blog/
│       ├── spec.md                  # Spec Kit 기능 명세 (무엇을, 왜)
│       ├── review.md                # 통합본 대조 검토
│       ├── plan.md                  # 구현 계획 (기술 스택, 구조, Constitution Check)
│       ├── research.md              # 기술 결정과 이유, 확정한 설정값
│       ├── data-model.md            # ERD와 테이블 설계
│       ├── quickstart.md            # 로컬 실행과 P1 확인 순서
│       ├── contracts/
│       │   ├── pages.md             # 화면 주소와 권한
│       │   └── api.md               # 화면 JS가 부르는 JSON API
│       └── checklists/
│           └── requirements.md      # 명세 품질 체크리스트
└── docs/                            # 원본 문서 (수정하지 않고 참고용으로 보관)
    └── 1팀_블로그_통합_기능명세서.md  # 팀 통합본 v0.2, spec.md의 기준 문서
```

## 다음 단계

1. `/speckit.constitution`: 프로젝트 원칙 v1.0.0 작성 (2026-10-08)
2. `/speckit.clarify`: 미결정 사항 모두 정리 완료 (2026-10-07)
3. `/speckit.plan`: 기술 스택(Django 5.2 + MySQL 8.4), 화면 주소, ERD (2026-10-08)
4. `/speckit.tasks`: 작업 목록 (다음 단계) → `/speckit.implement`

Spec Kit 1.1(`specify init`)의 스크립트·템플릿·명령을 저장소에 넣어 두었습니다(constitution은 우리 것 유지). 명령을 돌리기 전에 기능 폴더를 한 번 지정합니다. 이 값은 `.specify/feature.json`에 저장되며 커밋하지 않습니다.

```bash
SPECIFY_FEATURE_DIRECTORY=specs/001-blog bash .specify/scripts/bash/check-prerequisites.sh --json
```
