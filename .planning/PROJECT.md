# PROJECT.md — OmniInventory

## What This Is

OmniInventory is the definitive inventory management addon for World of Warcraft 3.3.5a (WotLK). It provides a unified bag interface with smart categorization, multiple view modes (Grid, Flow, List), custom rule engine, bank support, economic integrations, and forward-compatible architecture designed for portability to Retail.

## Core Value

**One sentence:** The best bag addon for WoW 3.3.5a — combining Bagnon's simplicity, AdiBags' smart sorting, and ArkInventory's configurability without the performance issues.

## Context

- **Current state:** v2.1 "The Definitive Bag Addon" and v2.2 deferred features complete. Milestone v2.3 in planning.
- **Milestone v2.3 goal:** Retrofit features from modern Retail bag addons (BetterBags, ArkInventory, Retail Bagnon) that provide massive UX value for WoW 3.3.5a players.
- **Tech stack:** Lua 5.1, WoW 3.3.5a API, no external dependencies (self-contained)
- **Architecture:** Layered (UI → Logic → Data → API Shim), forward-compatible with Retail via OmniC_Container shim

## Current Milestone: v2.3 "Modern Bag Features"

**Goal:** Retrofit features from modern Retail bag addons (BetterBags, ArkInventory, Retail Bagnon) that provide massive UX value for WoW 3.3.5a players.

**Target features:**
- Virtual Stacks — ArkInventory-style: combine multiple partial stacks of the same item into one visual stack with a total count.
- Empty Slot Compression — Instead of rendering 80 empty slots, show a single "Empty (28)" section or a compact grid of empty slots.
- Right-Click Item Context Menu — Right-click an item for actions: "Add to Category", "Pin", "Search Similar", "Send to Alt", "Disenchant".
- Gear Set Integration — Filter/view items by equipment set membership. Show "Part of Set: Tank" in tooltips.

## Requirements

### Validated (Existing)

- ✓ Multi-mode view engine (Grid, Flow, List)
- ✓ Smart item categorization (Quest, Equipment, Consumables, Trade Goods)
- ✓ Custom rule engine with condition-based and Lua expression rules
- ✓ Rule engine sandbox safety (infinite loop protection via fuel limit)
- ✓ Rule matching optimization (itemID index, sorted cache)
- ✓ Stable merge sort (eliminates "dancing items")
- ✓ Event bucketing (coalesces rapid BAG_UPDATE events)
- ✓ Object pooling (zero GC churn)
- ✓ Bank support with offline viewing
- ✓ Sell Junk button at vendors
- ✓ Search bar with real-time filtering
- ✓ Quick filter buttons (All, New, Quest, Gear, Cons, Junk)
- ✓ Minimap button
- ✓ Options panel (scale, view mode, sort mode)
- ✓ Masque support for button skins
- ✓ Fade-in animation
- ✓ Pawn upgrade arrows integration
- ✓ Category Editor UI
- ✓ Favorites/pin system
- ✓ Auto-sort on close option
- ✓ Bug Fixes & Performance — nil references fixed, binding scan cached, event scope fixed
- ✓ Restack / Compress Stacks across bags
- ✓ Item Level Overlay on gear icons
- ✓ Cooldown Spirals on consumables/trinkets
- ✓ Durability Indicator on damaged gear
- ✓ Profession Bag Highlighting
- ✓ Tooltip Total Count (bags + bank + alts)
- ✓ Smart Auto-Vendor Junk with threshold
- ✓ Bag Bar (equipped bags + swap)
- ✓ Offline Alt Bank Viewer UI
- ✓ Gear Set Assignment (Ctrl+Right-click)
- ✓ Usage-Based Sorting
- ✓ Per-Category Collapse
- ✓ Custom Themes (dark/glass/classic)
- ✓ Guild Bank Support

### Active (Milestone v2.3)

- [ ] Virtual Stacks — combine partial stacks into one visual stack with total count
- [ ] Empty Slot Compression — compact empty slots into a single section or grid
- [ ] Right-Click Item Context Menu — Add to Category, Pin, Search Similar, Send to Alt, Disenchant
- [ ] Gear Set Integration — filter/view by equipment set, tooltip set name

### Out of Scope (v2.3)

- Localization (L10n) — deferred to post-release
- Retail port — future milestone
- Deep Auctionator/TSM integration — basic hooks only
- Full gear set auto-swap — only viewing/filtering in this milestone
- Cross-realm alt support — same realm only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Lua 5.1 / WoW 3.3.5a target | User's primary game version | Active |
| API Shim layer for forward compatibility | Enables future Retail port with minimal changes | Active |
| No external libraries | Self-contained addon, zero dependency issues | Active |
| Event bucketing over direct handlers | Prevents frame drops during mass looting | Active |
| Object pooling for frames | Eliminates GC stutter in long sessions | Active |
| Sandboxed Lua expressions for rules | Power user feature, requires safety hardening | Needs improvement |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-22 — Milestone v2.3 started*
