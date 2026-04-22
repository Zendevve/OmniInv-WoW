# REQUIREMENTS.md — OmniInventory

## Completed Requirements (Previous Milestones)

### Stability & Bug Fixes
- ✓ STAB-05: Fix nil `closeBtn` reference in `UI/Frame.lua:221`
- ✓ STAB-06: Fix `SnapshotInventory` scope bug in `Omni/Events.lua:198`
- ✓ STAB-07: Fix missing `FireEvent` API calls in `Omni/Rules.lua`
- ✓ STAB-08: Add missing `CloseBag` global override in `Core.lua`
- ✓ STAB-09: All render loops maintain pcall error boundaries
- ✓ STAB-10: Event bucketing must not drop events during rapid combat looting

### Performance
- ✓ PERF-04: Cache tooltip binding scan results (avoid O(n²) scans during bag open)
- ✓ PERF-05: Object pool aggressively releases unused frames after bag close
- ✓ PERF-06: Frame creation remains lazy; no pre-creation on login

### Quality of Life
- ✓ QOL-01: User can restack/compress partial stacks across all bags
- ✓ QOL-02: Item level (iLvl) shown as small text overlay on gear icons
- ✓ QOL-03: Cooldown spirals shown on consumables and trinkets
- ✓ QOL-04: Durability indicator (red corner overlay) on gear below 20% durability
- ✓ QOL-05: Profession bag highlighting — slots matching bag type get subtle tint
- ✓ QOL-06: Search history — dropdown of recent searches in search bar

### Information & Integration
- ✓ INFO-01: Tooltip shows total item count: "Bags: X | Bank: Y | Alts: Z"
- ✓ INFO-02: Smart auto-vendor junk — auto-sell grey items at merchant with gold threshold
- ✓ INFO-03: Bag Bar — display equipped bags; click empty slot to equip bag from inventory
- ✓ INFO-04: New item flash enhancement + "Clear New" header button
- ✓ INFO-05: Category Editor shows "Matches X items" feedback per rule

### Advanced Features
- ✓ ADV-01: Offline Alt Bank Viewer — dropdown to view any alt's inventory and bank
- ✓ ADV-02: Gear Set Assignment — right-click gear → assign to Tank/Heal/DPS
- ✓ ADV-03: Usage-based sorting option — most-used items sort to top
- ✓ ADV-04: Per-category collapse — click category header to collapse/expand; persist per character

### v2.2 Deferred (Completed)
- ✓ Gear Set Assignment (Ctrl+Right-click)
- ✓ Usage-Based Sorting
- ✓ Per-Category Collapse
- ✓ Custom Themes (dark/glass/classic)
- ✓ Guild Bank Support

## Milestone v2.3 Requirements

### Virtual Stacks
| ID | Requirement | Priority |
|----|-------------|----------|
| VIRT-01 | User can enable virtual stacking to combine multiple partial stacks of the same item into one visual stack with total count | High |
| VIRT-02 | Virtual stacks display total item count across all bags and bank | High |
| VIRT-03 | Shift+click on a virtual stack initiates split from a real partial stack | Medium |
| VIRT-04 | Virtual stacking respects existing sort order and category grouping | Medium |

### Empty Slot Compression
| ID | Requirement | Priority |
|----|-------------|----------|
| EMPTY-01 | Empty slots are compressed into a single "Empty (N)" section or compact grid instead of rendering individual slots | High |
| EMPTY-02 | User can toggle empty slot compression on/off via options | Medium |
| EMPTY-03 | Clicking the compressed empty slot section expands it to show individual slots temporarily | Low |
| EMPTY-04 | Empty slot compression updates dynamically as items are added or removed | High |

### Item Context Menu
| ID | Requirement | Priority |
|----|-------------|----------|
| MENU-01 | Right-clicking an item opens a context menu with actions: Add to Category, Pin, Search Similar, Send to Alt, Disenchant | High |
| MENU-02 | Context menu actions integrate with existing systems (categories, pins, search, mail, disenchant) | High |
| MENU-03 | Context menu filters actions by item type (e.g., Disenchant only on valid items) | Medium |
| MENU-04 | Context menu closes on Esc or outside click | Low |

### Gear Set Integration
| ID | Requirement | Priority |
|----|-------------|----------|
| GSET-01 | Items belonging to an equipment set are tagged and filterable by set membership | High |
| GSET-02 | Tooltip shows "Part of Set: [SetName]" for items in an equipment set | High |
| GSET-03 | User can filter inventory view to show only items from a specific gear set | Medium |
| GSET-04 | Gear set integration works with Blizzard Equipment Manager and common set addons | Medium |

## Future Requirements (Post-v2.3)

- Full BetterBags-style bag skinning
- Retail-style reagent bag support (not applicable to 3.3.5a)
- Advanced item tagging system
- Cross-realm alt support

## Out of Scope (v2.3)

| Item | Reason |
|------|--------|
| Localization (L10n) | Deferred to post-release — English only |
| Retail port | Future milestone — 3.3.5a is primary target |
| Deep AH integration | Basic price hooks sufficient; full integration adds complexity |
| Full gear set auto-swap | Only viewing/filtering in this milestone; auto-swap is out of scope |
| Cross-realm alt support | Same realm only for v2.3 |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| VIRT-01 | Phase 11 | Pending |
| VIRT-02 | Phase 11 | Pending |
| VIRT-03 | Phase 11 | Pending |
| VIRT-04 | Phase 11 | Pending |
| EMPTY-01 | Phase 12 | Pending |
| EMPTY-02 | Phase 12 | Pending |
| EMPTY-03 | Phase 12 | Pending |
| EMPTY-04 | Phase 12 | Pending |
| MENU-01 | Phase 13 | Pending |
| MENU-02 | Phase 13 | Pending |
| MENU-03 | Phase 13 | Pending |
| MENU-04 | Phase 13 | Pending |
| GSET-01 | Phase 14 | Pending |
| GSET-02 | Phase 14 | Pending |
| GSET-03 | Phase 14 | Pending |
| GSET-04 | Phase 14 | Pending |

---
*Last updated: 2026-04-22 — Milestone v2.3 requirements defined*
