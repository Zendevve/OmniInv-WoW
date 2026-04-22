# REQUIREMENTS.md — OmniInventory

## Milestone v2.1 Requirements

### Stability & Bug Fixes

| ID | Requirement | Priority |
|----|-------------|----------|
| STAB-05 | Fix nil `closeBtn` reference in `UI/Frame.lua:221` (options button crash) | Critical |
| STAB-06 | Fix `SnapshotInventory` scope bug in `Omni/Events.lua:198` (local function called as method) | Critical |
| STAB-07 | Fix missing `FireEvent` API calls in `Omni/Rules.lua` (calling non-existent method) | Critical |
| STAB-08 | Add missing `CloseBag` global override in `Core.lua` | Critical |
| STAB-09 | All render loops must maintain pcall error boundaries (verify completeness) | High |
| STAB-10 | Event bucketing must not drop events during rapid combat looting | Medium |

### Performance

| ID | Requirement | Priority |
|----|-------------|----------|
| PERF-04 | Cache tooltip binding scan results (avoid O(n²) scans during bag open) | Critical |
| PERF-05 | Object pool must aggressively release unused frames after bag close | Medium |
| PERF-06 | Frame creation must remain lazy; no pre-creation on login | Medium |

### Quality of Life

| ID | Requirement | Priority |
|----|-------------|----------|
| QOL-01 | User can restack/compress partial stacks across all bags (Alt+click bag icon) | High |
| QOL-02 | Item level (iLvl) shown as small text overlay on gear icons (toggleable) | High |
| QOL-03 | Cooldown spirals shown on consumables and trinkets using `CooldownFrameTemplate` | High |
| QOL-04 | Durability indicator (red corner overlay) on gear below 20% durability | Medium |
| QOL-05 | Profession bag highlighting — slots matching bag type get subtle tint | Medium |
| QOL-06 | Search history — dropdown of recent searches in search bar | Low |

### Information & Integration

| ID | Requirement | Priority |
|----|-------------|----------|
| INFO-01 | Tooltip shows total item count: "Bags: X | Bank: Y | Alts: Z" on hover | High |
| INFO-02 | Smart auto-vendor junk — auto-sell grey items at merchant with gold threshold | High |
| INFO-03 | Bag Bar — display equipped bags; click empty slot to equip bag from inventory | High |
| INFO-04 | New item flash enhancement — more prominent glow + "Clear New" header button | Medium |
| INFO-05 | Category Editor shows "Matches X items" feedback for each rule | Low |

### Advanced Features

| ID | Requirement | Priority |
|----|-------------|----------|
| ADV-01 | Offline Alt Bank Viewer — dropdown to view any alt's inventory and bank | High |
| ADV-02 | Gear Set Assignment — right-click gear → "Assign to Set: Tank/Heal/DPS" | Medium |
| ADV-03 | Usage-based sorting option — most-used items sort to top | Low |
| ADV-04 | Per-category collapse — click category header to collapse/expand; persist per character | Low |

## v2 Requirements (Future Milestones)

- Localization (L10n) support
- Guild Bank support
- Item Set Manager integration
- Retail port (Dragonflight/War Within)
- Deep Auctionator/TSM integration
- Custom theme/skin presets

## Out of Scope (v2.1)

| Item | Reason |
|------|--------|
| Localization (L10n) | Deferred to post-release — English only for v2.1 |
| Guild Bank support | High complexity, low usage in 3.3.5a; future milestone |
| Retail port | Future milestone — 3.3.5a is primary target |
| Deep AH integration | Basic price hooks sufficient; full integration adds complexity |
| Custom themes | Deferred to v2.2 polish phase |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| STAB-05 | Phase 6 | Pending |
| STAB-06 | Phase 6 | Pending |
| STAB-07 | Phase 6 | Pending |
| STAB-08 | Phase 6 | Pending |
| STAB-09 | Phase 6 | Pending |
| STAB-10 | Phase 6 | Pending |
| PERF-04 | Phase 6 | Pending |
| PERF-05 | Phase 10 | Pending |
| PERF-06 | Phase 6 | Pending |
| QOL-01 | Phase 7 | Pending |
| QOL-02 | Phase 7 | Pending |
| QOL-03 | Phase 7 | Pending |
| QOL-04 | Phase 7 | Pending |
| QOL-05 | Phase 7 | Pending |
| QOL-06 | Phase 10 | Pending |
| INFO-01 | Phase 8 | Pending |
| INFO-02 | Phase 8 | Pending |
| INFO-03 | Phase 8 | Pending |
| INFO-04 | Phase 8 | Pending |
| INFO-05 | Phase 10 | Pending |
| ADV-01 | Phase 9 | Pending |
| ADV-02 | Phase 9 | Pending |
| ADV-03 | Phase 9 | Pending |
| ADV-04 | Phase 9 | Pending |

---
*Last updated: 2026-04-22 after v2.1 milestone start*
