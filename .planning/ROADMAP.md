# ROADMAP.md — OmniInventory

## Completed Phases (Previous Milestones)

### Phase 6: Bug Fixes & Performance Hardening
**Goal:** Eliminate all critical Lua errors and fix performance bottlenecks
**Requirements:** STAB-05, STAB-06, STAB-07, STAB-08, STAB-09, STAB-10, PERF-04, PERF-06
**Status:** Completed

### Phase 7: Essential Quality of Life
**Goal:** Add the missing features every modern bag addon must have
**Requirements:** QOL-01, QOL-02, QOL-03, QOL-04, QOL-05
**Status:** Completed

### Phase 8: Information Powerhouse
**Goal:** Build data-rich features that no competitor has
**Requirements:** INFO-01, INFO-02, INFO-03, INFO-04, INFO-05
**Status:** Completed

### Phase 9: Advanced Power User
**Goal:** Features that make power users switch to OmniInventory
**Requirements:** ADV-01, ADV-02, ADV-03, ADV-04
**Status:** Completed

### Phase 10: Polish & Compatibility
**Goal:** Final hardening, documentation, and compatibility audit
**Requirements:** PERF-05, QOL-06
**Status:** Completed

## Phase Structure (Milestone v2.3)

### Phase 11: Virtual Stacks Engine
**Goal:** Implement ArkInventory-style virtual stacking for partial stacks across bags and bank.
**Requirements:** VIRT-01, VIRT-02, VIRT-03, VIRT-04
**Success Criteria:**
1. Multiple partial stacks of the same item display as a single stack with total count.
2. Total count updates correctly when items are added or removed.
3. Shift+click on a virtual stack initiates split from a real partial stack.
4. Virtual stacks integrate with Grid, Flow, and List view modes without Lua errors.

### Phase 12: Empty Slot Compression
**Goal:** Compress empty slots into a compact representation to save screen real estate.
**Requirements:** EMPTY-01, EMPTY-02, EMPTY-03, EMPTY-04
**Success Criteria:**
1. Empty slots collapse into a single "Empty (N)" section when compression is enabled.
2. Toggle in options panel turns compression on/off instantly.
3. Clicking compressed section expands to show individual empty slots temporarily.
4. Compression updates dynamically as inventory changes.

### Phase 13: Item Context Menu System
**Goal:** Build a right-click context menu framework and integrate item actions.
**Requirements:** MENU-01, MENU-02, MENU-03, MENU-04
**Success Criteria:**
1. Right-clicking any item opens a context menu with relevant actions.
2. "Add to Category" opens category picker and assigns item.
3. "Pin" toggles item's pinned status.
4. "Search Similar" filters inventory by item name or type.
5. "Send to Alt" opens mail frame pre-addressed if at mailbox.
6. "Disenchant" appears only for disenchantable items and triggers casting.
7. Menu closes on Esc or outside click.

### Phase 14: Gear Set Integration
**Goal:** Integrate with WoW's equipment sets to tag, filter, and display set membership.
**Requirements:** GSET-01, GSET-02, GSET-03, GSET-04
**Success Criteria:**
1. Items in an equipment set show "Part of Set: [Name]" in tooltips.
2. Filter button or dropdown allows viewing only items from a specific set.
3. Set membership updates when equipment sets are modified.
4. Integration works with Blizzard Equipment Manager and common set addons.

### Phase 15: Integration & Hardening
**Goal:** Ensure all new features work together, performance is acceptable, and WotLK constraints are respected.
**Requirements:** (Cross-cutting stability and performance for v2.3 features)
**Success Criteria:**
1. All four features can be enabled simultaneously without Lua errors.
2. Virtual stacks combined with empty compression produce a stable layout.
3. Context menu actions work correctly on virtual stack items.
4. Tooltip scanning for gear sets uses cached data to avoid stalls.
5. Memory usage remains stable during extended play sessions.
6. All features respect SavedVariables size limits.

## Requirement Mapping

| Phase | Requirements |
|-------|--------------|
| 11 | VIRT-01, VIRT-02, VIRT-03, VIRT-04 |
| 12 | EMPTY-01, EMPTY-02, EMPTY-03, EMPTY-04 |
| 13 | MENU-01, MENU-02, MENU-03, MENU-04 |
| 14 | GSET-01, GSET-02, GSET-03, GSET-04 |
| 15 | (Cross-cutting stability) |

## Coverage Validation

- **Total new requirements:** 16
- **Requirements mapped:** 16
- **Coverage:** 100%

---
*Last updated: 2026-04-22 — Milestone v2.3 roadmap created*
