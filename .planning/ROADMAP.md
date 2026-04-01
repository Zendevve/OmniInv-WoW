# ROADMAP.md — OmniInventory

## Phase Structure

### Phase 5A: Rule Engine Hardening
**Goal:** Make the custom rule engine safe and performant
**Requirements:** STAB-01, PERF-01, CODE-01
**Success Criteria:**
1. Sandboxed expressions cannot infinite-loop (instruction count or timeout protection)
2. Rule matching is O(N+M) or better with caching/indexing
3. Rules.lua documents sandbox environment and safety measures

### Phase 5B: Async Data & Event Reliability
**Goal:** Fix item display issues and event timing
**Requirements:** STAB-03, STAB-04, PERF-03
**Success Criteria:**
1. Items no longer show as "Miscellaneous" when data is cached
2. Event bucketing timing prevents UI sluggishness during combat looting
3. Frame creation is lazy and doesn't cause frame drops

### Phase 5C: Cross-Character Features
**Goal:** Enable viewing items across alts
**Requirements:** FEAT-01, FEAT-03
**Success Criteria:**
1. UI shows items from other characters
2. Tooltips display "Also on: Alt (20)" count

### Phase 5D: Polish & Documentation
**Goal:** Final polish for beta release
**Requirements:** FEAT-02, FEAT-04, CODE-02, CODE-03, STAB-02, PERF-02
**Success Criteria:**
1. Search history works
2. Category Editor shows match count
3. API.lua documents version differences
4. UI uses layout constants
5. All render loops have error boundaries
6. Object pool is aggressively managed

---

## Requirement Mapping

| Phase | Requirements |
|-------|--------------|
| 5A | STAB-01, PERF-01, CODE-01 |
| 5B | STAB-03, STAB-04, PERF-03 |
| 5C | FEAT-01, FEAT-03 |
| 5D | FEAT-02, FEAT-04, CODE-02, CODE-03, STAB-02, PERF-02 |

---
*Last updated: 2026-04-01 after initialization*
