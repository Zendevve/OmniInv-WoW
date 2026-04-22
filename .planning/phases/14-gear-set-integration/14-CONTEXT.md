# Phase 14: Gear Set Integration - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Integrate with WoW's equipment sets (Blizzard Equipment Manager and common set addons) to tag, filter, and display set membership. This phase delivers automatic detection of set membership, tooltip indicators, inventory filtering by set, and bag category organization.

**In scope:**
- Automatic detection of Blizzard Equipment Manager sets via `GetNumEquipmentSets` / `GetEquipmentSetItemIDs`
- Tooltip line showing set membership ("Part of Sets: [Name1], [Name2]")
- Quick filter integration for viewing items from a specific gear set
- Bag category organization for set items
- Event-driven cache refresh (`EQUIPMENT_SETS_CHANGED`)

**Out of scope:**
- Modifying Blizzard Equipment Manager sets (read-only integration)
- Gear set auto-swap (only viewing/filtering)
- Cross-realm alt set support
- New manual set creation UI (already exists from ADV-02)

</domain>

<decisions>
## Implementation Decisions

### Blizzard vs Manual Sets
- **D-01:** Merge conceptually — both manual sets (Ctrl+Right-click Tank/Heal/DPS) and Blizzard Equipment Manager sets are presented to the user as unified "sets". The source (manual vs Blizzard) is an implementation detail hidden from the user.
- **D-02:** Show both — if an item is in multiple sets (e.g., manual "Tank" + Blizzard "ProtWarrior"), all memberships are displayed. No single "winner"; all sets are equally valid.
- **D-03:** Cached with refresh — Scan `GetNumEquipmentSets()` on login to build an internal cache of Blizzard set memberships. Listen for `EQUIPMENT_SETS_CHANGED` to update the cache. Balances instant availability with minimal login overhead.
- **D-04:** Read-only Blizzard — Ctrl+Right-click assignment UI manages manual sets only. Blizzard sets are detected but never modified by OmniInventory. The addon does not call `SaveEquipmentSet` or any Blizzard set mutation API.

### Filter UI for Gear Sets
- **D-05:** Dropdown on Gear button — The existing "Gear" quick filter button gets a right-click dropdown listing all detected gear sets. Left-click shows all equipment (existing behavior). Right-click opens the set selector.
- **D-06:** Hide non-set items — When filtering by a specific set, only items in that set are shown. This is a true filter (like search), not dimming. Non-set items are hidden from view.
- **D-07:** Scrollable dropdown — The set selector is a simple scrollable dropdown menu with no artificial limit on set count. No pagination or "More Sets..." submenu.
- **D-08:** Show set name on button — When a specific set filter is active, the Gear button text changes to display the set name (e.g., "ProtWar"). When no set filter is active, it shows "Gear".

### Tooltip Presentation
- **D-09:** Gold/yellow color — The "Part of Sets" tooltip line uses standard WoW information color (`1, 0.82, 0`). Consistent with binding text and item level overlays.
- **D-10:** One line, comma-separated — Multiple set memberships are shown on a single line: "Part of Sets: Tank, ProtWarrior, PvP". Compact but complete.
- **D-11:** After binding info — Set information appears after Soulbound/Binds when picked up lines but before item stats/effects. Standard meta-info placement in WoW tooltips.
- **D-12:** No source distinction — The tooltip does not label whether a set is from Blizzard Equipment Manager or manually assigned. A set is a set to the user.

### Category Display in Bag
- **D-13:** Grouped under "Gear Sets" — All set items (manual + Blizzard) are organized into a single "Gear Sets" bag category. Within this category, items are visually labeled or sub-grouped by their set name. Avoids category proliferation.
- **D-14:** Priority: above Equipment, below New/Quest — The "Gear Sets" category appears after "New Items" and "Quest" but before "Equipment" and all other categories.
- **D-15:** First set only — An item appears once in the "Gear Sets" category, tagged with its primary (first alphabetically) set name. The tooltip shows all memberships. Avoids item duplication in the bag view.
- **D-16:** Unify logic — Both manual and Blizzard sets use the same category creation logic. This replaces the old behavior where manual sets created individual "Set: [Name]" categories. All set items now flow through the unified "Gear Sets" category.

### the agent's Discretion
- Exact dropdown frame implementation (using existing UI patterns)
- Cache invalidation strategy details (full rebuild vs incremental update on EQUIPMENT_SETS_CHANGED)
- Gear Sets category internal sub-grouping visual treatment
- Set name text truncation on the filter button (if set name is very long)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` — GSET-01 through GSET-04 requirements and traceability
- `.planning/ROADMAP.md` — Phase 14 goal, success criteria, and requirement mapping

### Existing Gear Set Code
- `OmniInventory/Omni/Data.lua` §264-331 — Existing manual gear set data layer (`GetGearSets`, `AddItemToGearSet`, `GetItemGearSets`, etc.)
- `OmniInventory/Omni/Categorizer.lua` §106-127 — Existing Blizzard Equipment Manager scan (`IsEquipmentSetItem`, `GetNumEquipmentSets`, `GetEquipmentSetItemIDs`)
- `OmniInventory/Omni/Categorizer.lua` §333-340 — Existing manual set category assignment ("Set: " prefix)

### UI & Filter Framework
- `OmniInventory/UI/Frame.lua` §644-744 — Quick filter bar, `SetQuickFilter()`, filter button creation, filter application logic
- `OmniInventory/UI/ItemButton.lua` §867-892 — Tooltip rendering pattern (`GameTooltip:AddLine`, `SetBagItem`, `SetHyperlink`)

### Architecture & Events
- `OmniInventory/Omni/Events.lua` — Event bucketing system; `EQUIPMENT_SETS_CHANGED` should be registered here
- `OmniInventory/Omni/API.lua` — API shim layer; may need Equipment Manager API wrappers for forward compatibility

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Omni.Data gear set API** — `GetGearSets()`, `GetItemGearSets(itemID)`, `IsItemInGearSet()` already exist for manual sets. Phase 14 should extend or parallel this for Blizzard sets.
- **Quick filter bar (`UI/Frame.lua`)** — Six static buttons with `SetQuickFilter()` logic. The "Gear" button can be enhanced with a right-click dropdown without restructuring the bar.
- **Tooltip pattern (`UI/ItemButton.lua`)** — `GameTooltip:AddLine(text, r, g, b)` is the established pattern. Set info can be injected in the existing `OnEnter` handler.
- **Categorizer category registration** — `Categorizer:RegisterCategory(name, priority, icon, color, filterFunc)` can register the new "Gear Sets" category.

### Established Patterns
- **Event-driven cache updates** — The Events.lua bucketing system coalesces rapid events. `EQUIPMENT_SETS_CHANGED` should follow this pattern.
- **SavedVariables separation** — `OmniInventoryDB.global` for account-wide data (manual sets already here); Blizzard sets are runtime-detected and don't need persistence.
- **Lazy loading** — Bank data loads on demand. Gear set cache should be available for both live and offline inventory views.
- **pcall error boundaries** — All render loops wrap item operations in pcall. Gear set lookups must not throw.

### Integration Points
- **Data layer:** New `Data:GetBlizzardGearSets()` or extension of `GetItemGearSets()` to also query Blizzard Equipment Manager
- **Categorizer:** Replace/adjust lines 333-340 to use unified "Gear Sets" category instead of individual "Set: [Name]" categories
- **Filter layer:** `Frame:SetQuickFilter()` needs to handle dynamic set filter names (not just static strings like "Equipment")
- **Tooltip layer:** `ItemButton:OnEnter()` needs to inject set info lines after binding text but before stats
- **Event layer:** Register `EQUIPMENT_SETS_CHANGED` in Events.lua to invalidate/rebuild the Blizzard set cache

</code_context>

<specifics>
## Specific Ideas

- The user consistently deferred all decisions to the agent across all four discussion areas. Decisions above reflect agent judgment.
- The existing manual gear set system should not be broken — backward compatibility for `OmniInventoryDB.global.gearSets` is required.
- The Gear button text changing to the set name is a clear visual indicator of active filter state, similar to how search highlighting works.
- "Gear Sets" as a single category avoids the visual clutter of 5+ individual "Set: X" categories taking up bag space.
</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 14-gear-set-integration*
*Context gathered: 2026-04-22*
