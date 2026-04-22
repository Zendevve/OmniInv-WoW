# Phase 14: Gear Set Integration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-22
**Phase:** 14-Gear Set Integration
**Areas discussed:** Blizzard vs Manual Sets, Filter UI for Gear Sets, Tooltip Presentation, Category Display in Bag

---

## Blizzard vs Manual Sets

| Option | Description | Selected |
|--------|-------------|----------|
| Keep separate | Manual Sets and Equipment Sets are different concepts with distinct UI labels | |
| Merge conceptually | Both are just "sets"; unified list, source hidden | ✓ |
| Replace manual with Blizzard | Deprecate manual; Blizzard sets are source of truth | |
| You decide | Agent decides | ✓ (agent chose Merge conceptually) |

**User's choice:** "You decide" (all 4 questions)
**Notes:** Agent chose: merge conceptually, show both memberships, cached-with-refresh scan, read-only Blizzard sets.

---

## Filter UI for Gear Sets

| Option | Description | Selected |
|--------|-------------|----------|
| Dropdown on Gear button | Right-click Gear button for set selector; left-click = all equipment | ✓ |
| Separate Sets filter button | Add new "Sets" button to quick filter bar | |
| Replace Gear button | Gear button cycles through detected sets | |
| You decide | Agent decides | ✓ (agent chose Dropdown on Gear button) |

**User's choice:** "You decide" (all 4 questions)
**Notes:** Agent chose: dropdown on Gear button, hide non-set items (true filter), scrollable dropdown, show set name on button when active.

---

## Tooltip Presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Class color | Match character class color | |
| Gold/yellow | Standard WoW information color | ✓ |
| Set-specific color | Unique color per set | |
| You decide | Agent decides | ✓ (agent chose Gold/yellow) |

**User's choice:** "You decide" (all 4 questions)
**Notes:** Agent chose: gold/yellow color, one line comma-separated, after binding info, no source distinction.

---

## Category Display in Bag

| Option | Description | Selected |
|--------|-------------|----------|
| Set: [Name] for all | Each set gets its own category | |
| Grouped under Gear Sets | All set items in one category with sub-labels | ✓ |
| Keep in Equipment | Set membership only via tooltip/filter | |
| You decide | Agent decides | ✓ (agent chose Grouped under Gear Sets) |

**User's choice:** "You decide" (all 4 questions)
**Notes:** Agent chose: grouped under "Gear Sets" category, priority above Equipment/below New-Quest, first-set-only display, unify logic for manual+Blizzard.

---

## the agent's Discretion

- All four discussion areas were fully deferred to the agent.
- User expressed no specific preferences or references.
- Decisions reflect standard WoW addon UX patterns and consistency with existing OmniInventory behavior.

## Deferred Ideas

None — discussion stayed within phase scope.

---

*Phase: 14-gear-set-integration*
*Discussion date: 2026-04-22*
