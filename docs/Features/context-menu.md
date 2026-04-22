# Item Context Menu

## What It Does

Right-clicking any item opens a context menu with relevant actions. This replaces the old behavior where right-clicking would use/equip the item — now all item interactions are centralized in a clean menu.

**To use an item:** Left-click it directly, or select "Use" from the context menu.

## Actions

| Action | When Enabled | Behavior |
|--------|-------------|----------|
| **Use** | Always (for real items) | Uses or equips the item |
| **Pin / Unpin** | Items with an itemID | Toggles pin status; pinned items sort to top |
| **Search Similar** | Items with a hyperlink | Sets search to the item's name |
| **Add to Category** | Items with an itemID | Opens Category Editor focused on this item |
| **Send to Alt** | Real bag items | Picks up item for mailing (mailbox must be open) |
| **Disenchant** | Green/blue/epic quality items | Starts disenchant cast on the item |

Disabled actions appear greyed out in the menu.

## How to Open

**Right-click any item** in Grid, Flow, or List view.

## How to Close

- Click anywhere outside the menu
- Press **Escape**
- Click a menu action (auto-closes)

## Interaction with Other Features

- **Virtual Stacks:** Right-clicking a virtual stack opens the menu. Actions resolve to the first source slot (same as left-click).
- **Empty Slots:** Empty slots do not show the context menu — they remain drop targets.
- **Secure Buttons:** Left-click still uses the secure action button for combat safety. Right-click is now handled entirely by Lua.

## Files

| File | Role |
|------|------|
| `UI/ContextMenu.lua` | Menu frame, action handlers, open/close logic |
| `UI/ItemButton.lua` | Right-click hook to open menu |
| `UI/Frame.lua` | `SetSearchText()` helper for Search Similar action |

## Verification Steps

1. **Open menu:**
   - Right-click any item
   - Expect: context menu appears near the cursor
   - Expect: all relevant actions are shown; invalid ones are greyed

2. **Use item:**
   - Right-click item → select "Use"
   - Expect: item is used/equipped

3. **Pin item:**
   - Right-click item → select "Pin / Unpin"
   - Expect: item pins/unpins; layout refreshes

4. **Search similar:**
   - Right-click item → select "Search Similar"
   - Expect: search box shows item name; inventory filters to matches

5. **Disenchant filtering:**
   - Right-click a grey item
   - Expect: "Disenchant" is greyed out
   - Right-click a green+ item
   - Expect: "Disenchant" is available

6. **Close behavior:**
   - Open menu, click outside
   - Expect: menu closes
   - Open menu, press Escape
   - Expect: menu closes

## Notes

- The context menu replaces the previous Shift+Right-click pin shortcut. Pin is now accessible via the menu.
- "Send to Alt" requires an open mailbox; it only picks up the item — you still need to address and send the mail manually.
- "Disenchant" requires the Disenchant spell (Enchanter profession).
