# ROADMAP.md — OmniInventory

## Phase Structure

### Phase 6: Bug Fixes & Performance Hardening
**Goal:** Eliminate all critical Lua errors and fix performance bottlenecks
**Requirements:** STAB-05, STAB-06, STAB-07, STAB-08, STAB-09, STAB-10, PERF-04, PERF-06
**Success Criteria:**
1. Bags open without Lua errors on fresh login and after /reload
2. Tooltip binding scan is cached — bag open time reduced by 50%+
3. `CloseBag()` correctly closes OmniInventory instead of showing default UI
4. Rule engine `FireEvent` calls use correct API or are removed
5. No event loss during rapid mass looting (combat test)
6. Frame remains lazy-initialized; no pre-allocation on login

### Phase 7: Essential Quality of Life
**Goal:** Add the missing features every modern bag addon must have
**Requirements:** QOL-01, QOL-02, QOL-03, QOL-04, QOL-05
**Success Criteria:**
1. Alt+click bag icon restacks all partial stacks across bags automatically
2. Gear icons show iLvl text overlay (toggleable via settings)
3. Consumables and trinkets display accurate cooldown spirals
4. Gear below 20% durability shows red corner overlay
5. Herb/mining bags tint matching item slots with subtle color

### Phase 8: Information Powerhouse
**Goal:** Build data-rich features that no competitor has
**Requirements:** INFO-01, INFO-02, INFO-03, INFO-04, INFO-05
**Success Criteria:**
1. Hovering any item shows tooltip count: "Bags: X | Bank: Y | Alts: Z"
2. Opening merchant auto-sells grey items if total value < user threshold
3. Bag bar displays all equipped bags with type icons; click empty slot to equip
4. New items have prominent glow; "Clear New" button clears all new flags
5. Category Editor shows "Matches X items" per rule

### Phase 9: Advanced Power User
**Goal:** Features that make power users switch to OmniInventory
**Requirements:** ADV-01, ADV-02, ADV-03, ADV-04
**Success Criteria:**
1. Dropdown in header allows viewing any alt's inventory and bank offline
2. Right-click gear → "Assign to Set" creates custom gear set categories
3. Sort mode "Usage" sorts most-used items to top (tracked over session)
4. Category headers are collapsible; state persists per character

### Phase 10: Polish & Compatibility
**Goal:** Final hardening, documentation, and compatibility audit
**Requirements:** PERF-05, QOL-06, (any deferred items)
**Success Criteria:**
1. Object pool aggressively releases frames after bag close (no memory bloat)
2. Search history dropdown works with up to 20 recent searches
3. Addon loads cleanly alongside AtlasLoot, Questie, DBM, Recount
4. All new features have manual in-game verification steps documented
5. Code style passes audit (no magic numbers, proper constants)

---

## Requirement Mapping

| Phase | Requirements |
|-------|--------------|
| 6 | STAB-05, STAB-06, STAB-07, STAB-08, STAB-09, STAB-10, PERF-04, PERF-06 |
| 7 | QOL-01, QOL-02, QOL-03, QOL-04, QOL-05 |
| 8 | INFO-01, INFO-02, INFO-03, INFO-04, INFO-05 |
| 9 | ADV-01, ADV-02, ADV-03, ADV-04 |
| 10 | PERF-05, QOL-06 |

## Coverage Validation

- **Total requirements:** 24
- **Requirements mapped:** 24
- **Coverage:** 100%

---
*Last updated: 2026-04-22 after v2.1 milestone start*
