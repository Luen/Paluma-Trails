# Architecture Decision Records

Short records of decisions that are expensive to reverse. Format: context,
decision, rationale, alternatives, consequences. Keep them under a page.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-mobile-framework.md) | Mobile framework: Flutter | Accepted |
| [0002](0002-website-strategy.md) | Website: Flutter web build first, static site later if needed | Accepted |
| [0003](0003-offline-map-stack.md) | Offline map: MapLibre GL + bundled vector PMTiles | Accepted |
| [0004](0004-hosting-and-backend.md) | Hosting and backend | Accepted / Proposed (report intake) |
| [0005](0005-repo-structure.md) | Monorepo layout | Accepted |
| [0006](0006-branching-and-releases.md) | Branching model and release flow | Accepted |
| [0007](0007-release-tooling.md) | Release tooling for store delivery: GitHub Actions + in-repo fastlane | Accepted |
| [0008](0008-content-editing.md) | Content editing: reviewed requests and source JSON | Accepted |

## Template

```markdown
# ADR NNNN: Title

- **Status:** Proposed | Accepted | Superseded by ADR-NNNN
- **Date:** YYYY-MM-DD
- **Issues:** #NN

## Context
## Decision
## Rationale
## Alternatives considered
## Consequences
```
