# Feature: Custom Rules Engine

## Purpose

The Custom Rules Engine allows advanced users to define their own logic for item categorization. It supports both a declarative condition-based format and highly flexible sandboxed Lua expressions.

## Related

- Feature: [Smart Categorization Engine](file:///d:/COMPROG/ZenBags-dev/docs/Features/categorizer.md)
- Code: `Omni/Rules.lua`

---

## Business Rules

1. Users can define multiple rules with different priorities.
2. Rules can be based on discrete conditions (e.g., `itemID equals 6948`) or Lua expressions.
3. Lua expressions are sandboxed for security.
4. Rules are evaluated after manual overrides but before default heuristics.

---

## Condition Operators

The engine supports the following operators for declarative rules:

| Operator | Description | Input Type |
|----------|-------------|------------|
| `equals` | Exact match | text |
| `not_equals` | Does not match | text |
| `contains` | Partial match (case-insensitive) | text |
| `starts_with` | Matches beginning of string | text |
| `greater_than` | Numeric comparison | number |
| `less_than` | Numeric comparison | number |
| `in_list` | Match any item in a comma-separated list | text |

---

## Supported Fields

Rules (and expressions) have access to the following item fields:

- `itemID` (number)
- `name` (string)
- `quality` (number: 0-7)
- `itemType` (string)
- `itemSubType` (string)
- `iLvl` (number)
- `stackCount` (number)
- `isBound` (boolean)
- `bagID`, `slotID` (numbers)

---

## Sandboxed Lua Expressions

For complex logic, users can write Lua expressions.

**Example:**
```lua
item.quality > 2 and item.iLvl > 200 and item.itemType == "Armor"
```

**Safe Environment:**
The engine provides access to safe string (`string.find`, `match`, etc.) and math (`math.floor`, `abs`, etc.) functions. Global variables and destructive APIs are blocked.

---

## Data Structure (SavedVariables)

```lua
OmniInventoryDB.customRules = {
    {
        id = "123456_7890",
        name = "My Raid Gear",
        enabled = true,
        priority = 5,
        category = "Raid Gear",
        conditions = {
            { field = "iLvl", operator = "greater_than", value = 245 },
            { field = "itemType", operator = "equals", value = "Armor" },
        },
    },
    {
        id = "987654_3210",
        name = "Hearthstone",
        expression = "itemID == 6948",
        category = "Essential",
    }
}
```

---

## Test Flows (In-Game Verification)

### Positive Flow: Condition-based Matching
1. Create a rule: `Name Contains "Flask"`, Category `Consumables`.
2. Move a Flask into the bag.
3. Verify item is in the `Consumables` section.

### Positive Flow: Expression-based Matching
1. Create a rule with expression: `item.quality == 4`.
2. Category `Epic Items`.
3. Verify all Purple items appear in `Epic Items`.

### Negative Flow: Disabled Rule
1. Disable a rule that matches an item.
2. Verify item falls back to its default category.

---

## Definition of Done
- [x] Operator logic implemented (`Omni/Rules.lua`)
- [x] Lua sandboxing verified
- [x] Categories correctly assigned via `Categorizer`
- [x] Rules persisted in `SavedVariables`
