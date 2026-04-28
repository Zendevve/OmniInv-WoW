# v2.3 Integration Test Matrix

> Manual in-game verification for all v2.3 features working together.

## Setup
- All four features enabled: Virtual Stacks, Empty Slot Compression, Context Menu, Gear Set Integration
- Bags contain a mix of: equipment (some in sets), consumables, quest items, trade goods, junk
- At least one equipment set configured in Blizzard Equipment Manager

## Test Scenarios

### 1. All Features Enabled — No Errors
- Open bags in Grid view → no Lua errors
- Switch to Flow view → no Lua errors, categories render
- Switch to List view → no Lua errors, list renders
- Open bank → no Lua errors
- Close bags → no Lua errors

### 2. Virtual Stacks + Empty Compression
- Enable both: no blank spaces between categories
- "Empty (N)" count matches visible empty space
- Toggle empty compression off → individual empty slots appear
- Toggle empty compression on → single compressed section

### 3. Context Menu + Virtual Stack Items
- Right-click a virtual stack (item with multiple sources)
- Click "Use Item" → consumes from correct source slot
- Right-click again → menu still works (doesn't use stale slot)

### 4. Gear Set Filter + Empty Compression
- Right-click Gear button → select a set
- Empty slot count updates to reflect filtered view
- Select "All Equipment" → empty count returns to normal

### 5. Toggle Features Rapidly
- Toggle virtual stacks on/off 5 times rapidly
- Toggle empty compression on/off 5 times rapidly
- Open/close bags between toggles
- No state corruption, no orphaned buttons

### 6. Extended Play Session (30+ min)
- Open bags, leave open for 30 minutes
- Observe memory via `/dump GetAddOnMemoryUsage("OmniInventory")`
- Memory should not continuously grow
- No FPS drops during bag open/close

### 7. Bank with All Features
- Open bank with all features enabled
- Categories render correctly
- Virtual stacks work with bank items
- Gear sets show for bank items

## Notes
- Test each scenario in all 3 view modes (Grid, Flow, List)
- If any error occurs, note the exact error message and steps to reproduce
- Expected: zero Lua errors, zero FPS drops, stable memory
