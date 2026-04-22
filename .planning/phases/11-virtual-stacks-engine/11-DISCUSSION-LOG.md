# Phase 11: Virtual Stacks Engine — Discussion Log

**Date:** 2026-04-22
**Phase:** 11 — Virtual Stacks Engine
**Milestone:** v2.3 "Modern Bag Features"

---

## Area 1: Stack Combination Layer

**Question:** Where in the pipeline should virtual stacks combine items?

**Options presented:**
- A: Data layer — Combine right after GetAllBagItems(), before categorization/sorting. Simplest pipeline, but clicks need mapping back to real slots.
- B: Render layer — Keep real items through sorting, combine only at render time. Real items intact for clicks, but category counts and sorting get complex.
- C: Hybrid — Combine at data layer but store source slots table on each virtual item. Best of both worlds — simple pipeline + rich interactions. Slightly more memory per item.

**User selected:** C (Hybrid) — Recommended option

**Rationale captured:** Keeps sorting and categorization simple while preserving rich interactions.

---

## Area 2: Click Behavior

**Question:** Which click behavior for virtual stacks?

**Options presented:**
- A: Smart consume — Pick the smallest partial stack first. Most efficient, but might feel unpredictable.
- B: FIFO bag order — Always pick bag 0 first, then 1, 2, 3, 4. Predictable and simple.
- C: Bank-aware FIFO — Use bags first, bank last (or vice versa). Respects current context. Default is deterministic; no popup needed.
- D: Shift+click to pick — Normal click uses default; Shift+click opens mini-popup to choose source slot. Full control but more UI.

**User selected:** C (Bank-aware FIFO) — Recommended option

**Rationale captured:** Respects user's current context. Doesn't accidentally consume bank items when managing bags.

---

## Area 3: Visual Differentiation

**Question:** How should virtual stacks look visually?

**Options presented:**
- A: Identical — No visual difference. Only the count is higher. Cleanest and most minimal.
- B: Subtle count color — Real stacks = white count. Virtual stacks = yellow/gold count. Minimal visual noise.
- C: Tiny overlay icon — Small '∞' or '≡' icon in a corner. Explicit and glanceable, but slightly more clutter.
- D: Tooltip indicator only — Stack looks identical. Tooltip says '(Virtual stack: 3 bags)' on hover. Zero visual clutter.

**User selected:** D (Tooltip indicator only) — Recommended option

**Rationale captured:** Zero visual clutter. Matches UX-first, minimal UI preference.

---

## Area 4: Tooltip Behavior

**Question:** What should the tooltip show for virtual stacks?

**Options presented:**
- A: Total count only — Just the total count. Simplest, no extra tooltip logic.
- B: Total + location breakdown — '47 total: Bags 30 | Bank 17'. Useful at-a-glance, minimal overlap with cross-char tooltip.
- C: Total + full source list — Lists every bag/slot with counts. Maximum transparency, but can get very long.
- D: Total + first 3 sources — '47 total: Bag 0 (12), Bag 1 (20), Bank (15)'. Balanced info without tooltip bloat.

**User selected:** D (Total + first 3 sources) — Recommended option

**Rationale captured:** Balanced information without tooltip bloat.

---

## Area 5: Scope of Virtual Stacking

**Question:** What criteria determine which items combine into virtual stacks?

**Options presented:**
- A: Same itemID only — All identical items combine regardless of binding or location. Simplest, maximum compression.
- B: Same itemID + binding — Don't combine soulbound with BoE. More accurate, but slightly less compression.
- C: Same itemID + bag type — Respects profession bag organization. Keeps herb bag herbs separate from regular bag herbs.
- D: Configurable — ItemID by default, with per-item 'don't combine' override. Maximum flexibility for power users.

**User selected:** D (Configurable) — Recommended option

**Rationale captured:** Maximum compression by default. Power users can opt out for specific items.

---

## Decisions Summary

| # | Area | Decision |
|---|------|----------|
| D-01 | Stack Combination Layer | Hybrid — combine at data layer with sourceSlots table |
| D-02 | Click Behavior | Bank-aware FIFO — bags first, bank last (context-aware) |
| D-03 | Visual Differentiation | Tooltip indicator only — stacks look identical |
| D-04 | Tooltip Behavior | Total + first 3 source locations |
| D-05 | Scope of Stacking | ItemID by default, per-item "don't combine" override |

---

## Deferred Ideas

- Shift+click split from virtual stack (VIRT-03) — Complex UX, defer to post-v2.3
- Same-itemID + binding status separation — Rejected in favor of configurable override
- Visual overlay icon for virtual stacks — Rejected in favor of tooltip-only indicator

---

*End of discussion log*
