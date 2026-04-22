# Phase 11: Virtual Stacks Engine - Context

**Gathered:** 2026-04-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Implement ArkInventory-style virtual stacking: combine multiple partial stacks of the same item across bags and bank into a single visual slot with a total count. This phase delivers the core virtual stack engine — data layer combination, visual rendering, click behavior, and tooltip integration.

**In scope:**
- Virtual item creation from real bag/bank items
- Visual rendering of virtual stacks in Grid, Flow, and List views
- Click behavior (use item from appropriate source slot)
- Tooltip showing virtual stack info
- Per-item "don't combine" override setting

**Out of scope:**
- Shift+click split from virtual stack (VIRT-03 — deferred to v2.3.x or later)
- Empty slot compression (Phase 12)
- Context menu actions on virtual stacks (Phase 13)
- Gear set integration (Phase 14)

</domain>

<decisions>
## Implementation Decisions

### Stack Combination Layer
- **D-01:** Hybrid approach — combine at data layer (after GetAllBagItems(), before Categorize/Sort), but store a `sourceSlots` table on each virtual item.
- **Rationale:** Keeps sorting and categorization simple (virtual items look like normal items) while preserving rich interactions (clicks, tooltips can resolve back to real slots).
- **Source slots format:** `{ {bagID, slotID, count}, ... }` — ordered by consumption priority.

### Click Behavior
- **D-02:** Bank-aware FIFO consumption — bags first (0→4), bank last. When viewing bank mode, reverse (bank first, bags last).
- **Rationale:** Respects user's current context. Doesn't accidentally consume bank items when managing bags.
- **Deterministic:** No popup, no prompt. First source slot in the list gets consumed on left-click.

### Visual Differentiation
- **D-03:** No visual difference between virtual and real stacks. Stacks look identical.
- **Rationale:** Zero visual clutter. Matches UX-first, minimal UI preference.
- **Virtual indicator:** Tooltip first line shows "(Virtual stack: N sources)".

### Tooltip Behavior
- **D-04:** Tooltip shows total count + first 3 source locations.
- **Format:** "47 total: Bag 0 (12), Bag 1 (20), Bank (15)"
- **Overflow:** If more than 3 sources, append "and X more".
- **Rationale:** Balanced information without tooltip bloat.

### Scope of Virtual Stacking
- **D-05:** Default: same itemID combines. Per-item "don't combine" override available via right-click context menu (Phase 13).
- **Override storage:** `OmniInventoryDB.char.virtualStackOverrides[itemID] = true`
- **Rationale:** Maximum compression by default. Power users can opt out for specific items.
- **Binding status NOT considered for stacking:** We combine soulbound + BoE. The override handles edge cases.

### Claude's Discretion
- Source slots table ordering algorithm (exact FIFO implementation details)
- Virtual item table schema (which fields to preserve/merge from real items)
- Performance optimization for source slot lookup during clicks

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Architecture & API
- `OmniInventory/Omni/API.lua` — API shim layer, binding scan cache, item info polyfills
- `OmniInventory/Omni/Categorizer.lua` — Item categorization pipeline (where virtual items enter)
- `OmniInventory/Omni/Sorter.lua` — Stable merge sort (must work with virtual items)
- `OmniInventory/Omni/Pool.lua` — Object pool for ItemButton frames

### UI & Rendering
- `OmniInventory/UI/Frame.lua` — Main frame, UpdateLayout(), RenderFlowView(), RenderListView()
- `OmniInventory/UI/ItemButton.lua` — Item button widget, SetItem(), UpdateCooldown(), tooltip handlers

### Data & Events
- `OmniInventory/Omni/Events.lua` — Event bucketing, BAG_UPDATE handling
- `OmniInventory/Omni/Data.lua` — SavedVariables management

### Existing Features (Related)
- `OmniInventory/docs/Features/categorizer.md` — Category system behavior
- `OmniInventory/docs/Features/main-frame.md` — Frame rendering pipeline

### Requirements
- `.planning/REQUIREMENTS.md` — VIRT-01 through VIRT-04 requirements

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Omni.Pool ("ItemButton")** — Already recycles item buttons. Virtual stacks reuse the same pool.
- **Omni.ItemButton:Create() / :Reset()** — Factory + cleanup pattern. Virtual stacks may need a `:SetVirtualItem()` variant or reuse `:SetItem()` with virtual item tables.
- **OmniC_Container.GetAllBagItems() / GetAllBankItems()** — Returns raw item tables. Virtual stack combiner runs immediately after these calls.

### Established Patterns
- **Item table schema:** `{ iconFileID, itemID, hyperlink, stackCount, quality, bagID, slotID, ... }`
- **Render loop:** UpdateLayout() → categorize → sort → RenderFlowView() or RenderListView()
- **pcall error boundaries:** Already wrapped around SetButtonItem() calls in render loop
- **Lazy loading:** Bank data loads on demand. Virtual stacks must handle both live and offline data.

### Integration Points
- **Data layer:** Virtual combiner sits between `OmniC_Container.GetAll*Items()` and `Omni.Categorizer:GetCategory()`
- **Render layer:** RenderFlowView() receives combined virtual items. No changes needed if virtual items follow same schema.
- **Click layer:** ItemButton:OnClick() needs to check if item is virtual → resolve to real bag/slot → call UseContainerItem(realBag, realSlot)
- **Tooltip layer:** ItemButton:OnEnter() needs virtual stack indicator + source breakdown

</code_context>

<specifics>
## Specific Ideas

- Virtual stacks should feel invisible — the user shouldn't need to "learn" a new UI pattern. It should just look like their bags got cleaner.
- Source slot list in tooltip should be ordered by consumption priority (bags 0→4, then bank) so the user can predict where the next click will pull from.
- "Don't combine" override is a Phase 13 integration point — the context menu action should toggle `OmniInventoryDB.char.virtualStackOverrides[itemID]`.
</specifics>

<deferred>
## Deferred Ideas

- **Shift+click split from virtual stack (VIRT-03)** — Complex UX. User would need to pick which source bag/slot to split from. Defer to post-v2.3.
- **Same-itemID + binding status separation** — User decided against this. Default is itemID-only with per-item override.
- **Visual overlay icon for virtual stacks** — User explicitly chose tooltip-only indicator to maintain minimal UI.

</deferred>

---

*Phase: 11-virtual-stacks-engine*
*Context gathered: 2026-04-22*
