---
phase: 11
phase_name: Virtual Stacks Engine
wave_count: 3
plans_count: 8
files_modified:
  - Omni/VirtualStacks.lua
  - Omni/Data.lua
  - UI/ItemButton.lua
  - UI/Options.lua
  - UI/Frame.lua
  - OmniInventory.toc
  - docs/Features/virtual-stacks.md
autonomous: true
requirements_addressed:
  - VIRT-01
  - VIRT-02
  - VIRT-04
---

# Phase 11: Virtual Stacks Engine — Plan

**Goal:** Implement ArkInventory-style virtual stacking: combine multiple partial stacks of the same item across bags and bank into a single visual slot with a total count.

**Approach:** Hybrid data-layer combination with `sourceSlots` table stored on each virtual item. Keeps sorting/categorization simple while preserving rich click/tooltip interactions.

---

## Wave 1: Core Engine

### Task 1: Create `Omni/VirtualStacks.lua` — Virtual Stack Combiner

<read_first>
- `OmniInventory/Omni/API.lua` — See `OmniC_Container.GetAllBagItems()`, `OmniC_Container.GetAllBankItems()`, and item table schema
- `OmniInventory/Omni/Categorizer.lua` — See item categorization pipeline entry point
- `OmniInventory/Omni/Sorter.lua` — See item table schema expected by sorter
</read_first>

<action>
Create `OmniInventory/Omni/VirtualStacks.lua` with:

1. **Module declaration:** `local addonName, Omni = ...` and `Omni.VirtualStacks = {}`

2. **Constants:**
   - `local MAX_SOURCES_IN_TOOLTIP = 3`
   - `local BAG_ORDER = {0, 1, 2, 3, 4}`
   - `local BANK_BAG_ORDER = {-1, 5, 6, 7, 8, 9, 10, 11}`

3. **`VirtualStacks:ShouldCombine(itemID)`** — Check if item should be virtually stacked:
   ```lua
   function VirtualStacks:ShouldCombine(itemID)
       if not itemID then return false end
       -- Check override
       if OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.virtualStackOverrides then
           if OmniInventoryDB.char.virtualStackOverrides[itemID] == true then
               return false
           end
       end
       return true
   end
   ```

4. **`VirtualStacks:CombineItems(items, isBankMode)`** — Main combiner function:
   - Group items by `itemID` using a temporary table
   - For each group with count > 1 (multiple real slots):
     - Create ONE virtual item representing the group
     - `stackCount` = sum of all real stacks
     - `sourceSlots` = ordered array of `{bagID, slotID, count}`
     - Order sourceSlots by consumption priority (bag order first, bank last; reverse when `isBankMode`)
     - Preserve: `itemID`, `hyperlink`, `iconFileID`, `quality`, `itemType`, `itemSubType`, `itemLevel`, `equipSlot`, `vendorPrice`
     - Set `isVirtual = true` flag
     - Set `bagID = sourceSlots[1].bagID`, `slotID = sourceSlots[1].slotID` (first source for tooltip fallback)
   - For groups with count == 1 (single real slot):
     - Pass through unchanged (but still set `isVirtual = false` or nil)
   - Return the combined item list

5. **`VirtualStacks:GetConsumptionSlot(virtualItem, isBankMode)`** — Resolve which real slot to consume from:
   - Returns `bagID, slotID` from first entry in `virtualItem.sourceSlots`
   - If sourceSlots is empty, return nil

6. **`VirtualStacks:GetTooltipText(virtualItem)`** — Build tooltip extra line:
   - "(Virtual stack: N sources)"
   - Then: "47 total: Bag 0 (12), Bag 1 (20), Bank (15)"
   - If sources > 3: show first 3 + "and X more"

</action>

<acceptance_criteria>
- `Omni/VirtualStacks.lua` exists and loads without Lua errors
- `Omni.VirtualStacks:CombineItems()` accepts a table of item tables and returns a table
- Calling with 3 Peacebloom stacks (bag0/slot5: 12, bag1/slot3: 20, bank/slot8: 15) returns 1 item with `stackCount = 47` and `sourceSlots` containing all 3 sources in bag-order priority
- Calling with 1 unique item returns it unchanged
- `Omni.VirtualStacks:ShouldCombine(itemID)` returns false when itemID is in `OmniInventoryDB.char.virtualStackOverrides`
</acceptance_criteria>

---

### Task 2: Integrate Virtual Combiner into Data Pipeline

<read_first>
- `OmniInventory/UI/Frame.lua` — See `Frame:UpdateLayout()` around line 1221
- `OmniInventory/Omni/VirtualStacks.lua` — The module created in Task 1
- `OmniInventory/Omni/Events.lua` — See event bucketing to understand when UpdateLayout is triggered
</read_first>

<action>
Modify `OmniInventory/UI/Frame.lua`:

1. In `Frame:UpdateLayout()`, after items are fetched (around line 1319: `items = OmniC_Container.GetAllBagItems()`), add:
   ```lua
   -- Virtual stack combination (before categorization)
   if Omni.VirtualStacks and OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.enableVirtualStacks ~= false then
       items = Omni.VirtualStacks:CombineItems(items, currentMode == "bank")
   end
   ```

2. The integration point is AFTER items are fetched but BEFORE categorization (line 1324):
   ```lua
   -- BEFORE this block:
   -- Categorize items and check for new items
   if Omni.Categorizer then
       for _, item in ipairs(items) do
           item.category = item.category or Omni.Categorizer:GetCategory(item)
   ```

3. Ensure offline/bank/alt viewing paths also get virtual stack treatment:
   - The alt viewing path (line 1226-1269) constructs items manually — virtual stacking should apply there too
   - The offline bank path (line 1277-1314) also constructs items manually — apply virtual stacking

4. Add a helper at the top of UpdateLayout to determine `isBankMode`:
   ```lua
   local isBankMode = (currentMode == "bank")
   ```

</action>

<acceptance_criteria>
- `UI/Frame.lua:UpdateLayout()` calls `Omni.VirtualStacks:CombineItems()` before categorization when `enableVirtualStacks` is true (default true)
- Virtual stacks are applied to live bags, live bank, offline bank, and alt inventory views
- `currentMode` is correctly passed as `isBankMode` to the combiner
</acceptance_criteria>

---

## Wave 2: UI Integration

### Task 3: Update `UI/ItemButton.lua` — Virtual Stack Clicks & Tooltips

<read_first>
- `OmniInventory/UI/ItemButton.lua` — See `ItemButton:OnClick()` (line 795), `ItemButton:OnEnter()` (line 866), `ItemButton:OnDragStart()` (line 914)
- `OmniInventory/Omni/VirtualStacks.lua` — See `GetConsumptionSlot()` and `GetTooltipText()`
</read_first>

<action>
Modify `OmniInventory/UI/ItemButton.lua`:

1. In `ItemButton:OnClick()` (around line 795):
   - Before resolving `bagID` and `slotID` for clicks, check if `button.itemInfo.isVirtual` is true
   - If virtual, call `Omni.VirtualStacks:GetConsumptionSlot(button.itemInfo)` to get the real `bagID, slotID` to use
   - Replace all subsequent references to `button.bagID` / `button.slotID` in the click handler with the resolved real slot
   - For drag operations (`OnDragStart` and `OnReceiveDrag`), also resolve virtual items to their first source slot

2. In `ItemButton:OnEnter()` (around line 866):
   - After `GameTooltip:Show()`, check if `button.itemInfo.isVirtual` is true
   - If virtual, add the virtual stack indicator lines:
     ```lua
     if button.itemInfo.isVirtual and Omni.VirtualStacks then
         local tooltipText = Omni.VirtualStacks:GetTooltipText(button.itemInfo)
         for _, line in ipairs(tooltipText) do
             GameTooltip:AddLine(line, 0.8, 0.8, 0.8)
         end
         GameTooltip:Show()
     end
     ```

3. Ensure `button.bagID` and `button.slotID` are set correctly for virtual items:
   - In `SetButtonItem()` or equivalent, when item is virtual, set `button.bagID = item.sourceSlots[1].bagID` and `button.slotID = item.sourceSlots[1].slotID` as fallback
   - But the click handler should still resolve dynamically via `GetConsumptionSlot()`

4. For cooldown display on virtual stacks:
   - A virtual stack may have multiple source slots with different cooldowns
   - Show cooldown on the first source slot only (simplest approach)
   - If first source has no cooldown but second does, user won't see it — acceptable tradeoff per CONTEXT.md

</action>

<acceptance_criteria>
- Left-clicking a virtual stack uses the correct real bag/slot (first in sourceSlots by priority)
- Dragging a virtual stack picks up the first source slot item
- Tooltip on virtual stack shows "(Virtual stack: N sources)" and source breakdown
- Right-click behavior (pin toggle) still works on virtual stacks (operates on itemID, not slot)
</acceptance_criteria>

---

### Task 4: Add Virtual Stack Toggle to `UI/Options.lua`

<read_first>
- `OmniInventory/UI/Options.lua` — See existing checkbox/slider patterns (lines 42-200)
- `OmniInventory/Omni/Data.lua` — See defaults structure and `MergeDefaults()`
</read_first>

<action>
1. In `OmniInventory/Omni/Data.lua`, add to `defaults.global`:
   ```lua
   enableVirtualStacks = true,
   ```

2. In `OmniInventory/UI/Options.lua`, add a checkbox for virtual stacks:
   - Position it in the general settings section
   - Label: "Enable Virtual Stacks"
   - Tooltip: "Combine partial stacks of the same item into one visual stack"
   - On toggle: set `OmniInventoryDB.global.enableVirtualStacks` and call `Omni.Frame:UpdateLayout()` if frame is shown

3. Ensure the checkbox reflects current setting on open:
   ```lua
   checkbox:SetChecked(OmniInventoryDB.global.enableVirtualStacks ~= false)
   ```

</action>

<acceptance_criteria>
- `OmniInventoryDB.global.enableVirtualStacks` defaults to true
- Options panel shows "Enable Virtual Stacks" checkbox
- Toggling the checkbox immediately refreshes the bag layout if open
- Setting persists across `/reload`
</acceptance_criteria>

---

### Task 5: Add SavedVariables Support for Override Storage

<read_first>
- `OmniInventory/Omni/Data.lua` — See `defaults.char` and `TogglePin()` pattern
- `OmniInventory/Omni/VirtualStacks.lua` — See `ShouldCombine()` which reads overrides
</read_first>

<action>
In `OmniInventory/Omni/Data.lua`:

1. Add to `defaults.char`:
   ```lua
   virtualStackOverrides = {},  -- { [itemID] = true }
   ```

2. Add helper methods:
   ```lua
   function Data:SetVirtualStackOverride(itemID, enabled)
       if not itemID then return end
       OmniInventoryDB.char.virtualStackOverrides = OmniInventoryDB.char.virtualStackOverrides or {}
       if enabled then
           OmniInventoryDB.char.virtualStackOverrides[itemID] = true
       else
           OmniInventoryDB.char.virtualStackOverrides[itemID] = nil
       end
   end

   function Data:GetVirtualStackOverride(itemID)
       if not itemID then return false end
       return OmniInventoryDB.char.virtualStackOverrides and OmniInventoryDB.char.virtualStackOverrides[itemID] == true
   end
   ```

3. These will be called by Phase 13's context menu action. For now, ensure the storage exists.

</action>

<acceptance_criteria>
- `OmniInventoryDB.char.virtualStackOverrides` defaults to empty table
- `Omni.Data:SetVirtualStackOverride(itemID, true)` adds item to overrides
- `Omni.Data:SetVirtualStackOverride(itemID, false)` removes item from overrides
- `Omni.Data:GetVirtualStackOverride(itemID)` returns correct boolean
- `VirtualStacks:ShouldCombine()` correctly respects override
</acceptance_criteria>

---

## Wave 3: Hookup & Verification

### Task 6: Update `OmniInventory.toc` to Load New Module

<read_first>
- `OmniInventory/OmniInventory.toc` — Current load order
</read_first>

<action>
Add `Omni\VirtualStacks.lua` to the Core Architecture section, after `Omni\Rules.lua` and before UI components:

```
Omni\Rules.lua
Omni\VirtualStacks.lua
```

</action>

<acceptance_criteria>
- `OmniInventory.toc` contains `Omni\VirtualStacks.lua` in the Core Architecture section
- Module loads without errors on login
</acceptance_criteria>

---

### Task 7: Create Feature Doc `docs/Features/virtual-stacks.md`

<read_first>
- `OmniInventory/docs/Features/` — Existing feature doc structure
- `OmniInventory/.planning/phases/11-virtual-stacks-engine/11-CONTEXT.md` — Phase context with decisions
</read_first>

<action>
Create `OmniInventory/docs/Features/virtual-stacks.md` documenting:

1. **What it does:** Combine partial stacks of the same itemID across bags/bank into one visual slot
2. **How to enable/disable:** Options panel checkbox or `/oi config`
3. **How it works:** Data-layer combination before categorization/sort
4. **Click behavior:** Uses first source slot by bag-order priority (bags 0→4, bank last)
5. **Tooltip info:** Shows total count + up to 3 source locations
6. **Per-item override:** Right-click → "Don't combine this item" (Phase 13 integration)
7. **Verification steps:**
   - Get 2 partial stacks of same item in different bags
   - Open bags — should show 1 slot with combined count
   - Click the stack — should consume from first bag
   - Hover — tooltip should show source breakdown
   - Disable in options — should show separate stacks again

</action>

<acceptance_criteria>
- `docs/Features/virtual-stacks.md` exists with all sections above
- Doc follows MCAF feature doc conventions (What, How, Why, Verification)
</acceptance_criteria>

---

### Task 8: In-Game Verification

<read_first>
- `OmniInventory/docs/Features/virtual-stacks.md` — Verification steps
- `OmniInventory/Omni/VirtualStacks.lua` — Implementation
- `OmniInventory/UI/Frame.lua` — Integration point
</read_first>

<action>
Perform manual in-game verification:

1. **Basic virtual stacking:**
   - Split a stack of Peacebloom (or any stackable item) into 2 bags
   - Open OmniInventory bags
   - Confirm: 1 visual slot showing combined count
   - Confirm: tooltip shows source breakdown

2. **Click behavior:**
   - Left-click the virtual stack
   - Confirm: item is consumed from bag 0 (or first bag with the item)
   - Confirm: count updates correctly

3. **Bank mode:**
   - Put same item in bag and bank
   - Switch to bank view
   - Confirm: virtual stack combines bag + bank items
   - Confirm: click consumes from bank first (bank-aware FIFO)

4. **Toggle:**
   - Open `/oi config`
   - Uncheck "Enable Virtual Stacks"
   - Confirm: bags show separate stacks again
   - Re-enable
   - Confirm: stacks recombine

5. **Edge cases:**
   - Full bags (no empty slots) — virtual stacks still work
   - Single unique items — pass through unchanged
   - Items with overrides — should not combine

</action>

<acceptance_criteria>
- Virtual stacks combine correctly in live bags
- Tooltip shows source breakdown
- Click consumes from correct source slot
- Toggle on/off works instantly
- No Lua errors during any test scenario
</acceptance_criteria>

---

## must_haves

1. `Omni/VirtualStacks.lua` exists and exports `CombineItems()`, `ShouldCombine()`, `GetConsumptionSlot()`, `GetTooltipText()`
2. Virtual stacks apply before categorization/sorting in `Frame:UpdateLayout()`
3. Clicking a virtual stack resolves to a real bag/slot and consumes correctly
4. Tooltip on virtual stack shows total count + source breakdown
5. Options toggle enables/disables virtual stacking instantly
6. `OmniInventory.toc` loads the new module
7. No Lua errors in any view mode (Grid, Flow, List)
8. Feature doc exists with verification steps

## Deferred to Phase 13

- Shift+click split from virtual stack (VIRT-03)
- Right-click "Don't combine this item" override toggle

---

*Plan created: 2026-04-22*
*Phase: 11 — Virtual Stacks Engine*
