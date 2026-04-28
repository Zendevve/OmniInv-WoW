# Phase 15: Integration & Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-28
**Phase:** 15-Integration & Hardening
**Areas discussed:** All deferred to agent

---

## Error Boundary Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Re-entrancy guard | Flag on UpdateLayout to prevent recursive calls | ✓ |
| pcall wrappers | Extend existing pcall pattern to UpdateLayout itself | ✓ |
| You decide | Agent decides | ✓ |

**User's choice:** "Do what you think is best next" (deferred all)
**Notes:** Agent chose: re-entrancy guard + pcall wrapper on UpdateLayout, guard all event handler callbacks, and fix the confirmed gear set filter / empty compression mismatch.

---

## Performance Validation

| Option | Description | Selected |
|--------|-------------|----------|
| In-game manual testing | Frame rate observation during specific scenarios | ✓ |
| Memory profiling | /dump GetAddOnMemoryUsage over extended sessions | ✓ |
| You decide | Agent decides | ✓ |

**User's choice:** Deferred all
**Notes:** Agent chose: manual in-game testing only (consistent with WoW addon constraints). No automated performance framework exists or is needed.

---

## SavedVariables Size Limits

| Option | Description | Selected |
|--------|-------------|----------|
| Audit only | Verify new keys stay under limits, no pruning needed | ✓ |
| Pruning strategy | Add cleanup for old data | |
| Monitoring | Add size warnings at runtime | |
| You decide | Agent decides | ✓ |

**User's choice:** Deferred all
**Notes:** Agent chose: audit-only approach. The blizzardSetCache is negligible (~150 entries for typical users). No pruning or runtime monitoring needed.

---

## Cross-Feature Edge Cases

| Option | Description | Selected |
|--------|-------------|----------|
| Structured test matrix | Documented multi-feature test scenarios | ✓ |
| Ad-hoc hardening | Fix bugs as found without structured testing | |
| You decide | Agent decides | ✓ |

**User's choice:** Deferred all
**Notes:** Agent chose: structured test matrix with 7 specific scenarios covering all four features enabled simultaneously, cross-feature interactions, and stability testing.

---

## the agent's Discretion

All four discussion areas were fully deferred to the agent. Decisions reflect the 6 roadmap success criteria plus findings from the codebase integration scout.

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 15-integration-hardening*
*Discussion date: 2026-04-28*
