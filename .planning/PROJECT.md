# PROJECT.md — OmniInventory

## What This Is

OmniInventory is the definitive inventory management addon for World of Warcraft 3.3.5a (WotLK). It provides a unified bag interface with smart categorization, multiple view modes (Grid, Flow, List), custom rule engine, bank support, economic integrations, and forward-compatible architecture designed for portability to Retail.

## Core Value

**One sentence:** The best bag addon for WoW 3.3.5a — combining Bagnon's simplicity, AdiBags' smart sorting, and ArkInventory's configurability without the performance issues.

## Context

- **Current state:** v2.0-alpha, Phases 1-4 complete (Foundation, Filter Engine, Visual Polish, Integrations)
- **Phase 5 pending:** Release v2.0-beta — production hardening, bug fixes, performance optimization
- **Tech stack:** Lua 5.1, WoW 3.3.5a API, no external dependencies (self-contained)
- **Architecture:** Layered (UI → Logic → Data → API Shim), forward-compatible with Retail via OmniC_Container shim

## Requirements

### Validated (Existing)

- ✓ Multi-mode view engine (Grid, Flow, List)
- ✓ Smart item categorization (Quest, Equipment, Consumables, Trade Goods)
- ✓ Custom rule engine with condition-based and Lua expression rules
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

### Active (Phase 5 — v2.0-beta)

- [ ] Rule engine sandbox safety (infinite loop protection)
- [ ] Performance optimization for large rule sets
- [ ] Cross-character item viewing UI
- [ ] Search history
- [ ] Tooltip enhancements (item count across alts)
- [ ] Error handling hardening

### Out of Scope (v2.0)

- Localization (L10n) — deferred to post-release
- Item Set Manager integration — future roadmap
- Retail port — future milestone
- Auctionator/TSM deep integration — basic hooks only

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
*Last updated: 2026-04-01 after initialization*
