# Virtual Stacks

## What It Does

Virtual Stacks combine multiple partial stacks of the same item across all bags (and bank, when viewing bank) into a single visual slot with a combined total count. This reduces visual clutter and makes inventory management feel cleaner — especially for players who keep large quantities of crafting materials, consumables, or trade goods scattered across multiple bags.

## How to Enable/Disable

- Open the options panel: `/oi config` or click the gear icon in the bag header
- Check/uncheck **"Enable Virtual Stacks"**
- Changes apply instantly — no `/reload` required

The setting is stored per-account (`OmniInventoryDB.global.enableVirtualStacks`) and defaults to **enabled**.

## How It Works

### Data Layer Combination

Virtual stacking happens **before** categorization and sorting, in `Frame:UpdateLayout()`:

```
GetAllBagItems() → VirtualStacks:CombineItems() → Categorize → Sort → Render
```

This means:
- Sorting and categorization work exactly as before
- Category headers show correct combined counts automatically
- The stable merge sort prevents "dancing items"

### Combination Criteria

By default, items with the **same `itemID`** are combined. Soulbound and BoE stacks of the same item are combined together.

Per-item overrides can be set (via right-click context menu in Phase 13) to prevent specific items from combining.

### Source Slot Tracking

Each virtual item stores a `sourceSlots` table:

```lua
{
    { bagID = 0, slotID = 5, count = 12 },
    { bagID = 1, slotID = 3, count = 20 },
    { bagID = -1, slotID = 8, count = 15 },
}
```

Source slots are ordered by **consumption priority**:
- **Bag mode:** Bags 0→4 first, then bank
- **Bank mode:** Bank first, then bags 0→4

This ensures clicking a virtual stack consumes from the most appropriate location based on context.

## Click Behavior

| Action | Behavior |
|--------|----------|
| Left-click | Uses item from first source slot (by priority) |
| Right-click | Uses item from first source slot (by priority) |
| Drag | Picks up item from first source slot |
| Shift+click (chat link) | Links item from first source slot |
| Ctrl+click (dressing room) | Opens dressing room for item from first source slot |

## Tooltip Info

Hovering a virtual stack shows:

```
(Virtual stack: 3 sources)
47 total: Backpack (12), Bag 1 (20), Bank (15)
```

If there are more than 3 source locations, only the first 3 are shown plus "and X more".

## Per-Item Override

> **Phase 13 integration.** Right-click an item → "Don't combine this item" to prevent it from virtual stacking. The override is stored per-character in `OmniInventoryDB.char.virtualStackOverrides`.

## Files

| File | Role |
|------|------|
| `Omni/VirtualStacks.lua` | Core combiner engine |
| `UI/Frame.lua` | Pipeline integration |
| `UI/ItemButton.lua` | Click resolution & tooltip |
| `UI/Options.lua` | Enable/disable toggle |
| `Omni/Data.lua` | Override storage helpers |

## Verification Steps

1. **Basic combination:**
   - Split a stack of Peacebloom (or any stackable item) into 2 different bags
   - Open OmniInventory bags
   - Expect: 1 visual slot showing combined count
   - Hover: tooltip shows source breakdown

2. **Click behavior:**
   - Left-click the virtual stack
   - Expect: item consumed from bag 0 (or first bag with the item)
   - Expect: count updates correctly

3. **Bank mode:**
   - Put same item in bag and bank
   - Switch to bank view
   - Expect: virtual stack combines bag + bank items
   - Click: expect consumption from bank first

4. **Toggle:**
   - Open `/oi config`
   - Uncheck "Enable Virtual Stacks"
   - Expect: bags show separate stacks
   - Re-enable: expect stacks recombine

5. **Edge cases:**
   - Full bags (no empty slots) — virtual stacks still work
   - Single unique items — pass through unchanged
   - Items with overrides — should not combine

## Deferred

- **Shift+click split from virtual stack** (VIRT-03) — Complex UX requiring source slot picker. Deferred to post-v2.3.
