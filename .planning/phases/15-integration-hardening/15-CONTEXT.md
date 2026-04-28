# Phase 15: Integration & Hardening - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Ensure all v2.3 features (Virtual Stacks, Empty Slot Compression, Context Menu, Gear Set Integration) work together without Lua errors, performance degradation, or memory issues. This is a **pure hardening phase** — no new capabilities. The deliverable is a stable, production-ready v2.3 milestone.

**In scope:**
- Error boundary hardening (re-entrancy guards, pcall gaps)
- Cross-feature integration fixes (gear set filter + empty compression mismatch)
- Performance optimization (cached lookups, hot path analysis)
- SavedVariables size audit and cleanup
- Manual test matrix verification

**Out of scope:**
- New features or capabilities
- UI redesigns
- Retail port compatibility work
- Localization (deferred to post-release)

</domain>

<decisions>
## Implementation Decisions

### Error Boundary Hardening
- **D-01:** Add re-entrancy guard to `Frame:UpdateLayout()` — a simple flag `self._updatingLayout` that prevents recursive calls. If a nested call is detected, it returns immediately.
- **D-02:** Wrap `Frame:UpdateLayout()` body in `pcall` so if any step in the pipeline throws, the guard is cleared and a Lua error is printed, preventing permanent lockout.
- **D-03:** All event handlers that call `UpdateLayout()` (BAG_UPDATE bucket, EQUIPMENT_SETS_CHANGED bucket, PLAYER_ENTERING_WORLD, BANKFRAME_OPENED, PLAYERBANKSLOTS_CHANGED) should use the guarded path — no direct calls to `UpdateLayout()` without going through the guard.

### Cross-Feature Integration Fixes
- **D-04:** Gear set filter must inform empty slot compression — when `activeGearSetFilter` is set, `CalculateEmptySlots()` should return a count that reflects the filtered view (i.e., only count empty slots that appear after set items are collapsed). Implementation: pass current item list to `CalculateEmptySlots()` so it can cross-reference which bag slots would actually show as empty in the current layout.
- **D-05:** ContextMenu actions must add an `isVirtual` guard — before any action that manipulates the item (UseItem, SendToAlt, Disenchant), re-validate that the resolved `bagID/slotID` still holds the expected item. If the source slot was consumed by a prior action, show "Item no longer available" and close the menu.
- **D-06:** Virtual stack items must have valid `bagID`/`slotID` fields (the first source slot). The existing behavior is adequate but should be documented as a dependency for ContextMenu. Ensure `GetConsumptionSlot()` is called before passing to ContextMenu (it already is at `ItemButton.lua:810-812`).

### Performance Hardening
- **D-07:** `BuildBlizzardSetCache()` must NOT be called from the categorization hot path. Currently `IsItemInAnySet()` → `GetAllSetMemberships()` → `GetBlizzardSetsForItem()` may trigger a cache rebuild if `blizzardItemToSets` is nil. Fix: ensure cache is always built before any categorization occurs (on login, per D-03 from Phase 14), and add an explicit nil guard that returns empty if cache isn't built yet.
- **D-08:** `GetAllSetMemberships()` should cache per-item results within a single `UpdateLayout()` cycle. Use a transient cache table that is cleared at the start of each render cycle. This avoids O(n × m) Blizzard set lookups where n = items and m = sets.
- **D-09:** Remove dead code `IsEquipmentSetItem()` from `Categorizer.lua:106-127` — it's no longer called in the pipeline (replaced by `IsItemInAnySet()` in Phase 14), but its presence in the file is confusing and it accesses `itemInfo.bagID/slotID` fields.

### SavedVariables Audit
- **D-10:** `OmniInventoryDB.char.blizzardSetCache` — verify this doesn't exceed ~50KB for users with many equipment sets. Each set stores `{ [itemID] = true }` entries. A user with 10 sets × 15 items each = ~150 entries = negligible. No pruning strategy needed.
- **D-11:** Validate that all v2.3 saved keys (`enableVirtualStacks`, `enableEmptySlotCompression`, `virtualStackOverrides`, `blizzardSetCache`) have proper defaults and don't cause errors when missing (nil-guards already in place per established patterns).

### Verification Matrix
- **D-12:** Manual test scenarios (in-game, no automation):
  1. All four features enabled simultaneously → no Lua errors, stable layout
  2. Virtual stacks + empty compression → no blank spaces, "Empty (N)" count correct
  3. Context menu on virtual stack item → "Use Item" consumes from correct source slot
  4. Gear set filter active + empty compression → empty count matches filtered view
  5. Toggle features on/off rapidly mid-session → no state corruption
  6. Extended play session (30+ min) → no memory growth via `/dump GetAddOnMemoryUsage("OmniInventory")`
  7. Bank viewing with all features → no errors, categories render correctly

### the agent's Discretion
- Exact re-entrancy guard implementation (flag placement, debug logging)
- Where to add additional nil-checks (audit all new code from phases 11-14)
- Whether to add a `/oi debug integration` slash command for test scenarios
- Exact test procedure details

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap & Requirements
- `.planning/ROADMAP.md` — Phase 15 goal and 6 success criteria
- `.planning/REQUIREMENTS.md` — Completed v2.3 requirements (VIRT-01..04, EMPTY-01..04, MENU-01..04, GSET-01..04)

### Prior Phase Context (v2.3 Features)
- `.planning/phases/11-virtual-stacks-engine/11-CONTEXT.md` — Virtual stack architecture decisions (combine layer, click behavior, tooltip)
- `.planning/phases/14-gear-set-integration/14-CONTEXT.md` — Gear set cache, filter UI, tooltip display decisions (D-01 through D-16)

### Core Files to Audit
- `UI/Frame.lua` §1400-1600 — UpdateLayout pipeline, gear set filter, empty compression integration
- `UI/Frame.lua` §1375-1395 — CalculateEmptySlots (unfiltered — needs gear set filter awareness)
- `UI/ItemButton.lua` §810-860 — OnClick bagID/slotID resolution for virtual items + ContextMenu call
- `UI/ContextMenu.lua` — All action handlers (UseItem, SendToAlt, Disenchant, Pin)
- `Omni/VirtualStacks.lua` — CombineItems, GetConsumptionSlot, CreateVirtualItem
- `Omni/Data.lua` §337-430 — BuildBlizzardSetCache, GetBlizzardSetsForItem, GetAllSetMemberships, IsItemInAnySet
- `Omni/Categorizer.lua` §106-127 — Dead code: IsEquipmentSetItem (should be removed)
- `Omni/Events.lua` §167,255 — BAG_UPDATE and EQUIPMENT_SETS_CHANGED handlers (both call UpdateLayout)
- `Core.lua` — OverrideBags, event registration, slash commands

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Event bucketing system (`Omni/Events.lua`)** — Already coalesces rapid events. EQUIPMENT_SETS_CHANGED and BAG_UPDATE already use it. The guard can be added to the callbacks without changing the bucketing infrastructure.
- **pcall pattern (`UI/Frame.lua:1771`)** — RenderFlowView already wraps item button rendering in pcall. The same pattern should be extended to UpdateLayout itself.
- **Object pool (`Omni/Pool.lua`)** — The pcall guard must ensure pool state is consistent if a render error occurs mid-cycle. If pool acquire succeeds but render fails, the button must be released.

### Established Patterns
- **Nil-guards before all API calls** — Every WoW API call is wrapped in `if X then ...` checks. New Phase 11-14 code follows this. The audit should verify no regressions.
- **SavedVariables defaults merging** — `Data.lua:74-82 MergeDefaults()` recursively fills missing keys. All v2.3 keys are in the defaults table or have inline nil-checks.
- **UpdateLayout async/delayed pattern** — Event bucketing (50ms delay) prevents spam. The re-entrancy guard adds synchronous protection on top.

### Integration Points (Cross-Feature Risk Map)
- **VirtualStacks → Categorizer:** `CombineItems()` runs before `GetCategory()` at `Frame.lua:1504-1512`. Virtual items have `bagID/slotID` from first source — this works but is a maintenance hazard.
- **VirtualStacks → ContextMenu:** `OnClick` resolves bagID/slotID via `GetConsumptionSlot()` before passing to ContextMenu at `ItemButton.lua:810-856`. The resolved coordinates are used correctly, but the unresolved `itemInfo` object is also passed.
- **GearSetFilter → EmptyCompression:** True filter removes items but `CalculateEmptySlots()` scans unfiltered bag slots at `Frame.lua:1555-1584`. **This is the only confirmed UX bug.**
- **GearSets → Categorization:** `IsItemInAnySet()` may trigger `BuildBlizzardSetCache()` in hot path at `Categorizer.lua:339`. **This is a performance risk if cache is stale.**
- **All → UpdateLayout:** No re-entrancy guard, no pcall wrapper. **This is the highest severity gap.**

</code_context>

<specifics>
## Specific Ideas

- The user deferred all decisions to the agent (consistent pattern from Phases 11-14).
- The confirmed UX bug (gear set filter + empty compression mismatch) must be fixed — not deferred.
- Performance is measured by in-game observation: no visible FPS drop, no stutter on bag open, no memory growth over sessions.
- The re-entrancy guard pattern should follow Lua's simple flag-and-return idiom, consistent with the addon's minimal-dependency philosophy.
</specifics>

<deferred>
## Deferred Ideas

- Routine in-game playtesting with all four features enabled — the test matrix (D-12) covers the main scenarios; extended soak testing is the user's responsibility after deployment.
- Cross-realm gear set support — the Blizzard cache is per-character, which is correct for v2.3 scope.

</deferred>

---

*Phase: 15-integration-hardening*
*Context gathered: 2026-04-28*
