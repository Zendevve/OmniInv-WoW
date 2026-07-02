# Plan: Combat-Safe Bag Toggle

## Problem
The bag cannot be opened or closed during combat. Pressing the keybinding (`/oi`, keybind, or global `ToggleAllBags`) has no effect.

## Root Cause
`Frame:Show()` and `Frame:Hide()` have partial pcall coverage — only `mainFrame.Show` and `mainFrame.Hide` are wrapped. All other code in these functions (CreateMainFrame, SetView, UpdateLayout, cleanup loops, PhysicalSortBags, RunTidy) is **not** pcall-protected. If any of that code throws an error during combat, the error propagates up through `Frame:Toggle()` → `Omni:Toggle()` → binding handler, and the entire toggle fails silently or with an error message.

Additionally, `Omni:Toggle()` itself has **no pcall protection**, so any error from the chain below kills the toggle.

## Fix

### 1. `Core.lua` — `Omni:Toggle()` (line 21–25)
Wrap the entire body in pcall so the binding always completes cleanly:

```lua
function Omni:Toggle()
    if self.Frame then
        pcall(self.Frame.Toggle, self.Frame)
    end
end
```

### 2. `Frame.lua` — `Frame:Show()` (line 5507–5541)
Restructure so that:
- Frame creation (CreateMainFrame + SetView + LoadPosition) is pcall-protected
- `mainFrame:Show()` via pcall is the next critical step (already is)
- All post-show work (ComputeShowSignature, fast-show path, UpdateLayout) is wrapped in a single pcall

```lua
function Frame:Show()
    if not mainFrame then
        pcall(function()
            currentView = GetSavedViewMode()
            selectedBagID = GetSavedBagFilter()
            self:CreateMainFrame()
            self:SetView(currentView)
            self:LoadPosition()
        end)
    end

    if not mainFrame then return end

    pcall(mainFrame.Show, mainFrame)

    pcall(function()
        local sig = ComputeShowSignature()
        local viewAllowsFastShow = (currentView == "grid" or currentView == "bag")
        local canFastShow = hasRenderedOnce
            and not pendingCombatRender
            and lastRenderedShowSignature ~= nil
            and sig == lastRenderedShowSignature
            and viewAllowsFastShow

        if canFastShow then
            self:UpdateBagIconTextures()
            self:UpdateBagIconVisuals()
            self:UpdateSlotCount()
            self:UpdateMoney()
            self:RefreshCombatContent({ _trigger = true })
            if searchText and searchText ~= "" then
                self:ApplySearch(searchText)
            end
        else
            self:UpdateLayout(nil, { reason = "show_open" })
        end
    end)
end
```

### 3. `Frame.lua` — `Frame:Hide()` (line 5544–5583)
Same pattern — protect the critical hide call, then pcall-wrap all cleanup:

```lua
function Frame:Hide()
    if not mainFrame then return end

    pcall(mainFrame.Hide, mainFrame)

    pcall(function()
        vendorFlowLayoutFreeze = nil
        wasMerchantOpen = false
        ClearMap(optimisticFlowRefreshWatches)
        ClearArray(itemButtons)

        if Omni.NewItems then
            wipe(Omni.NewItems)
        end

        for _, byBag in pairs(slotButtons) do
            for _, btn in pairs(byBag) do
                if btn then
                    btn._cachedSearchName = nil
                    btn._cachedSearchNameLower = nil
                    if btn.newGlow then
                        if btn.newGlow.pulse then
                            btn.newGlow.pulse:Stop()
                        end
                        btn.newGlow:Hide()
                    end
                end
            end
        end

        if not InCombat()
                and OmniInventoryDB and OmniInventoryDB.global
                and OmniInventoryDB.global.autoSortOnClose then
            Frame:PhysicalSortBags()
        end

        if not InCombat() and Omni.Features and Omni.Features.ShouldAutoTidyOnClose
                and Omni.Features:ShouldAutoTidyOnClose() then
            Omni.Features:RunTidy()
        end
    end)
end
```

## Files Changed
- `OmniInventory/Core.lua` — lines 21–25 (`Omni:Toggle`)
- `OmniInventory/UI/Frame.lua` — lines 5507–5541 (`Frame:Show`), lines 5544–5583 (`Frame:Hide`)

## Verification
- Toggle bag open/close via keybinding during combat (enter combat, press keybind → bag opens; press again → bag closes)
- Toggle via slash command `/oi` during combat
- Toggle via global override (e.g., Blizzard's default bag keybind) during combat
- Open bag before combat, enter combat, close it
- Open bag, enter combat, verify content shows combat grid fallback, then close
- Verify normal (out-of-combat) toggle still works with full layout/render
