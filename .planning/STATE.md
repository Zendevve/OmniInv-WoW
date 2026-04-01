# STATE.md — OmniInventory

## Current Phase

**Phase 5B: Async Data & Event Reliability**

## Status

- Planning initialized: 2026-04-01
- Phase 5A completed: 2026-04-01
  - Rule engine sandbox safety: keyword blocking, instruction counter (fuel limit), recursion depth limit
  - Rule matching optimization: sorted rules cache, itemID index for O(1) lookups
  - Cache invalidation on all rule changes (Add, Remove, Update, Toggle)
- Ready to begin Phase 5B execution

## Milestones

- [x] Phase 1: Foundation
- [x] Phase 2: Filter Engine (Visual Editor)
- [x] Phase 3: Visual Polish & Masque
- [x] Phase 4: Integrations (Offline Bank, Pawn)
- [ ] Phase 5: Release v2.0-beta
  - [x] 5A: Rule Engine Hardening ✅
  - [ ] 5B: Async Data & Event Reliability
  - [ ] 5C: Cross-Character Features
  - [ ] 5D: Polish & Documentation

## Phase 5A Changes

- `Omni/Rules.lua`: Added 3-layer sandbox safety
  - Layer 1: Keyword blocking (while, for, repeat, goto)
  - Layer 2: Instruction counter (MAX_FUEL = 1000 operations)
  - Layer 3: Error boundary for timeout/recursion errors
- `Omni/Rules.lua`: Optimized rule matching
  - Sorted rules cache (invalidated on RULES_CHANGED)
  - itemID index for O(1) lookups on direct itemID matches
  - Cache invalidation in AddRule, RemoveRule, UpdateRule, ToggleRule

## Notes

- Project health check completed (docs/project_health_check.md)
- GET_ITEM_INFO_RECEIVED already handled in Events.lua
- pcall error boundaries already added in RenderFlowView and RenderListView
- Rule engine sandbox now has infinite loop protection
- Rule matching optimized for large rule sets

---
*Last updated: 2026-04-01 after Phase 5A completion*
