# REQUIREMENTS.md — OmniInventory

## v1 Requirements (Phase 5 — v2.0-beta)

### Stability & Safety

| ID | Requirement | Priority |
|----|-------------|----------|
| STAB-01 | Rule engine sandbox must prevent infinite loops (instruction count limit or timeout) | Critical |
| STAB-02 | Render loops must use pcall error boundaries (already partially done in FlowView/ListView) | Critical |
| STAB-03 | Async item data loading must not show "Miscellaneous" placeholder for cached items | High |
| STAB-04 | Event bucketing timing must not cause UI sluggishness during combat looting | Medium |

### Performance

| ID | Requirement | Priority |
|----|-------------|----------|
| PERF-01 | O(N*M) rule matching must be optimized for 50+ rules and 200+ items | High |
| PERF-02 | Object pool must be aggressively managed to prevent memory bloat in long sessions | Medium |
| PERF-03 | Frame creation/lazy initialization must not cause frame drops on first open | Medium |

### Features

| ID | Requirement | Priority |
|----|-------------|----------|
| FEAT-01 | Cross-character item viewing UI (see items across alts) | High |
| FEAT-02 | Search history (remember recent searches) | Medium |
| FEAT-03 | Tooltip enhancements: "Also on: Alt (20)" item count across characters | Medium |
| FEAT-04 | Category Editor: show "Matches X items" feedback for rules | Low |

### Code Quality

| ID | Requirement | Priority |
|----|-------------|----------|
| CODE-01 | Rules.lua must document sandbox environment and safety measures | Medium |
| CODE-02 | API.lua must document which functions are 3.3.5a vs Retail | Medium |
| CODE-03 | UI positioning should use layout constants, not magic numbers | Low |

## v2 Requirements (Future)

- Localization (L10n) support
- Item Set Manager integration
- Retail port (Dragonflight/War Within)
- Deep Auctionator/TSM integration
- Custom theme/color picker

## Out of Scope

| Item | Reason |
|------|--------|
| Localization (L10n) | Deferred to post-release — English only for v2.0-beta |
| Item Set Manager | Future roadmap — not critical for bag management |
| Retail port | Future milestone — 3.3.5a is primary target |
| Deep AH integration | Basic price hooks sufficient; full integration adds complexity |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STAB-01 | Phase 5 | Pending |
| STAB-02 | Phase 5 | Partially done |
| STAB-03 | Phase 5 | Pending |
| STAB-04 | Phase 5 | Pending |
| PERF-01 | Phase 5 | Pending |
| PERF-02 | Phase 5 | Pending |
| PERF-03 | Phase 5 | Pending |
| FEAT-01 | Phase 5 | Pending |
| FEAT-02 | Phase 5 | Pending |
| FEAT-03 | Phase 5 | Pending |
| FEAT-04 | Phase 5 | Pending |
| CODE-01 | Phase 5 | Pending |
| CODE-02 | Phase 5 | Pending |
| CODE-03 | Phase 5 | Pending |

---
*Last updated: 2026-04-01 after initialization*
