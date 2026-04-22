# Empty Slot Compression

## What It Does

Empty Slot Compression reduces visual clutter by collapsing all empty bag slots into a single compact "Empty (N)" indicator. This saves significant screen real estate — instead of rendering 80+ empty slot buttons, you see one concise summary.

When expanded, individual empty slots are shown as normal drop targets, allowing you to place items into specific bags.

## How to Enable/Disable

- Open the options panel: `/oi config` or click the gear icon in the bag header
- Check/uncheck **"Compress Empty Slots"**
- Changes apply instantly — no `/reload` required

The setting is stored per-account (`OmniInventoryDB.global.enableEmptySlotCompression`) and defaults to **enabled**.

## How It Works

### Compression Logic

Empty slots are calculated after items are fetched but before rendering:

```
GetAllBagItems() → CalculateEmptySlots() → Sort → Render
```

For each bag (0-4), the engine counts:
- Total slots (`GetContainerNumSlots`)
- Minus occupied slots (where `GetContainerItemInfo` returns a texture)

### Visual Representation

**Compressed (default):**
- A single slot-sized button with dark grey background
- Text: "Empty (28)" in grey
- Click to expand and see individual empty slots

**Expanded:**
- Individual empty slot buttons rendered in the normal item grid
- Each slot is a proper drop target — drag an item onto it to place it in that bag/slot
- Right-click on any empty slot to collapse back to compressed view

### Section Placement

In **Flow** and **Bag** views, empty slots appear as a collapsible category section at the bottom:
- Header: "Empty Slots (N)" with [+]/[-] toggle
- Compressed: single "Empty (N)" button below header
- Expanded: full grid of empty slots

In **Grid** view, empty slots render at the bottom without a header.

In **List** view, empty slots appear as a single separator row: "Empty Slots (N)".

## Click Behavior

| State | Action | Result |
|-------|--------|--------|
| Compressed | Left-click | Expands to show individual empty slots |
| Expanded empty slot | Left-click + holding item | Places item in that slot |
| Expanded empty slot | Right-click | Collapses back to compressed view |
| Section header (Flow/Bag) | Click | Toggles expand/collapse |

## Interaction with Other Features

- **Virtual Stacks:** Empty slot compression is independent — both can be enabled simultaneously
- **Category Collapse:** Empty slots section uses the same collapse mechanism as item categories
- **ItemButton Pooling:** Expanded empty slots reuse pooled ItemButton frames; compressed uses a lightweight custom frame

## Files

| File | Role |
|------|------|
| `UI/Frame.lua` | Empty slot calculation, rendering in Flow/Grid/List views |
| `UI/ItemButton.lua` | Empty slot click handling (drop targets), OnClick reset |
| `UI/Options.lua` | Enable/disable toggle |
| `Omni/Data.lua` | SavedVariables default |

## Verification Steps

1. **Basic compression:**
   - Open bags with many empty slots
   - Expect: single "Empty (N)" button at bottom
   - Expect: correct count matches total free slots

2. **Expansion:**
   - Left-click compressed "Empty (N)" button
   - Expect: individual empty slots rendered
   - Expect: count matches number of slots shown

3. **Drop target:**
   - Pick up an item from inventory
   - Click an expanded empty slot
   - Expect: item placed in that bag/slot

4. **Collapse:**
   - Right-click any expanded empty slot
   - Expect: returns to compressed "Empty (N)" view

5. **Toggle:**
   - Open `/oi config`
   - Uncheck "Compress Empty Slots"
   - Expect: no empty slot section shown (current behavior)
   - Re-enable: compressed section returns

6. **Dynamic updates:**
   - Add/remove items while bags are open
   - Expect: empty slot count updates automatically

## Notes

- Empty slot compression does not apply to bank view (bank slots are not tracked the same way)
- The compressed frame is a lightweight custom frame (not an ItemButton) to avoid pool contamination
- Empty slots in expanded mode use the standard ItemButton with `nil` itemInfo, which now supports drop targets via the fixed `OnClick` handler
