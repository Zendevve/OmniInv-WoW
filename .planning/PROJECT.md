# PROJECT.md — OmniInventory

## What This Is

OmniInventory is the definitive inventory management addon for World of Warcraft 3.3.5a (WotLK). It provides a unified bag interface with smart categorization, multiple view modes (Grid, Flow, List), custom rule engine, bank support, economic integrations, and forward-compatible architecture designed for portability to Retail.

## Core Value

**One sentence:** The best bag addon for WoW 3.3.5a — combining Bagnon's simplicity, AdiBags' smart sorting, and ArkInventory's configurability without the performance issues.

## Context

- **Current state:** v2.0-beta delivered (Phases 1-5A complete). Milestone v2.1 in planning.
- **Milestone v2.1 goal:** Transform OmniInventory from "solid beta" to "best in class" — fix critical bugs, add essential QoL, and build information-rich tools.
- **Tech stack:** Lua 5.1, WoW 3.3.5a API, no external dependencies (self-contained)
- **Architecture:** Layered (UI → Logic → Data → API Shim), forward-compatible with Retail via OmniC_Container shim

## Current Milestone: v2.1 "The Definitive Bag Addon"

**Goal:** Fix all critical bugs, add essential missing QoL, and build information-rich tools that make OmniInventory objectively the best WotLK 3.3.5a bag addon.

**Target features:**
- Bug Fixes & Performance — Fix 5 critical Lua errors, cache tooltip scans, fix nil references
- Restack / Compress Stacks — Combine partial stacks across bags
- Item Level Overlay — Show iLvl on gear icons (toggleable)
- Cooldown Spirals — Show remaining cooldown on consumables/trinkets
- Durability Indicator — Red overlay on gear below 20% durability
- Profession Bag Highlighting — Tint slots matching profession bag types
- Tooltip Total Count — "Bags: 12 | Bank: 5 | Alts: 3" on item hover
- Smart Auto-Vendor Junk — Auto-sell greys at merchant (with gold threshold)
- Bag Bar — Show equipped bags; click empty slot to equip from inventory
- Offline Alt Bank Viewer — Dropdown to view any alt's inventory/bank
- Gear Set Assignment — Right-click gear → assign to Tank/Heal/DPS custom sections

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

### Active (Milestone v2.1)

- [ ] Bug Fixes — nil references, missing CloseBag override, event handler scope
- [ ] Performance — cache tooltip binding scans, reduce BAG_UPDATE churn
- [ ] Restack / Compress Stacks across bags
- [ ] Item Level Overlay on gear icons
- [ ] Cooldown Spirals on consumables/trinkets
- [ ] Durability Indicator on damaged gear
- [ ] Profession Bag Highlighting
- [ ] Tooltip Total Count (bags + bank + alts)
- [ ] Smart Auto-Vendor Junk with threshold
- [ ] Bag Bar (equipped bags + swap)
- [ ] Offline Alt Bank Viewer UI
- [ ] Gear Set Assignment (right-click → custom sets)

### Out of Scope (v2.1)

- Localization (L10n) — deferred to post-release
- Guild Bank support — high complexity, low usage; future milestone
- Retail port — future milestone
- Deep Auctionator/TSM integration — basic hooks only
- Custom theme/skin presets — deferred to v2.2 polish phase

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
*Last updated: 2026-04-22 after v2.1 milestone start*
