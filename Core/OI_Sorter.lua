-- =============================================================================
-- OmniInventory Stable Merge Sort
-- =============================================================================
-- Deterministic, stable sort. Same inputs = same outputs.
-- =============================================================================

local addonName, OI = ...

OI.Sorter = {}
local Sorter = OI.Sorter

local band = (bit and bit.band) or function(a, b)
    local result, bitVal = 0, 1
    while a > 0 or b > 0 do
        if (a % 2 == 1) and (b % 2 == 1) then result = result + bitVal end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitVal = bitVal * 2
    end
    return result
end

-- =============================================================================
-- Merge Sort
-- =============================================================================

local function Merge(arr, left, mid, right, cmp)
    local n1, n2 = mid - left + 1, right - mid
    local L, R = {}, {}
    for i = 1, n1 do L[i] = arr[left + i - 1] end
    for j = 1, n2 do R[j] = arr[mid + j] end

    local i, j, k = 1, 1, left
    while i <= n1 and j <= n2 do
        if cmp(L[i], R[j]) or not cmp(R[j], L[i]) then
            arr[k] = L[i]; i = i + 1
        else
            arr[k] = R[j]; j = j + 1
        end
        k = k + 1
    end
    while i <= n1 do arr[k] = L[i]; i = i + 1; k = k + 1 end
    while j <= n2 do arr[k] = R[j]; j = j + 1; k = k + 1 end
end

local function MergeSort(arr, left, right, cmp)
    if left < right then
        local mid = math.floor((left + right) / 2)
        MergeSort(arr, left, mid, cmp)
        MergeSort(arr, mid + 1, right, cmp)
        Merge(arr, left, mid, right, cmp)
    end
end

-- =============================================================================
-- Comparators
-- =============================================================================

local function GetCategoryPriority(item)
    if not item then return 99 end
    if item.category and OI.Categorizer then
        local catInfo = OI.Categorizer:GetCategoryInfo(item.category)
        return catInfo and catInfo.priority or 99
    end
    if OI.Categorizer then
        local catName = OI.Categorizer:GetCategory(item)
        local catInfo = OI.Categorizer:GetCategoryInfo(catName)
        return catInfo and catInfo.priority or 99
    end
    return 99
end

local function GetItemName(item)
    if not item then return "zzz" end
    local link = item.hyperlink or item.link
    if not link then return "zzz" end
    return GetItemInfo(link) or "zzz"
end

local function GetItemLevel(item)
    if not item then return 0 end
    local link = item.hyperlink or item.link
    if not link then return 0 end
    local _, _, _, iLvl = GetItemInfo(link)
    return iLvl or 0
end

local function DefaultComparator(a, b)
    if not a then return false end
    if not b then return true end

    local pinnedA = a.itemID and OI.Data and OI.Data:IsPinned(a.itemID)
    local pinnedB = b.itemID and OI.Data and OI.Data:IsPinned(b.itemID)
    if pinnedA and not pinnedB then return true end
    if pinnedB and not pinnedA then return false end

    local catA, catB = GetCategoryPriority(a), GetCategoryPriority(b)
    if catA ~= catB then return catA < catB end

    local qualA, qualB = a.quality or 0, b.quality or 0
    if qualA ~= qualB then return qualA > qualB end

    local ilvlA, ilvlB = GetItemLevel(a), GetItemLevel(b)
    if ilvlA ~= ilvlB then return ilvlA > ilvlB end

    local nameA, nameB = GetItemName(a), GetItemName(b)
    if nameA ~= nameB then return nameA < nameB end

    local stackA, stackB = a.stackCount or 1, b.stackCount or 1
    if stackA ~= stackB then return stackA > stackB end

    local posA = ((a.bagID or 0) * 100) + (a.slotID or 0)
    local posB = ((b.bagID or 0) * 100) + (b.slotID or 0)
    return posA < posB
end

local function QualityComparator(a, b)
    if not a then return false end
    if not b then return true end
    if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
    return DefaultComparator(a, b)
end

local function NameComparator(a, b)
    if not a then return false end
    if not b then return true end
    local nameA, nameB = GetItemName(a), GetItemName(b)
    if nameA ~= nameB then return nameA < nameB end
    return DefaultComparator(a, b)
end

local function ILvlComparator(a, b)
    if not a then return false end
    if not b then return true end
    if GetItemLevel(a) ~= GetItemLevel(b) then return GetItemLevel(a) > GetItemLevel(b) end
    return DefaultComparator(a, b)
end

local COMPARATORS = {
    category = DefaultComparator,
    quality = QualityComparator,
    name = NameComparator,
    ilvl = ILvlComparator,
}

-- =============================================================================
-- Public API
-- =============================================================================

function Sorter:Sort(items, mode)
    if not items or #items == 0 then return {} end
    local sorted = {}
    for i, item in ipairs(items) do sorted[i] = item end
    local cmp = COMPARATORS[mode] or DefaultComparator
    MergeSort(sorted, 1, #sorted, cmp)
    return sorted
end

function Sorter:SortCategorized(categorizedItems)
    local result = {}
    for cat, items in pairs(categorizedItems) do
        result[cat] = self:Sort(items, "category")
    end
    return result
end

function Sorter:GetModes() return { "category", "quality", "name", "ilvl" } end

function Sorter:GetDefaultMode()
    return OI.db and OI.db.global and OI.db.global.sortMode or "category"
end

function Sorter:SetDefaultMode(mode)
    if COMPARATORS[mode] then OI.db.global.sortMode = mode end
end

-- =============================================================================
-- Physical Sort State Machine
-- =============================================================================

local isSorting = false
local sortBank = false
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame.elapsed = 0
timerFrame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed >= 0.8 then
        self:Hide()
        if Sorter:IsPhysicalSorting() then Sorter:ProcessNextPhysicalMove() end
    end
end)

function Sorter:IsPhysicalSorting() return isSorting end

function Sorter:PhysicalSort(isBank)
    if isSorting then return end
    if InCombatLockdown() then OI:Print("Cannot sort in combat.") return end
    isSorting = true
    sortBank = isBank or false
    OI:Print("Sorting bags...")
    self:ProcessNextPhysicalMove()
end

function Sorter:StopPhysicalSort()
    isSorting = false
    timerFrame:Hide()
    if OI.Frame then OI.Frame:UpdateLayout() end
end

function Sorter:ProcessNextPhysicalMove()
    if not isSorting then return end
    if InCombatLockdown() then self:StopPhysicalSort() OI:Print("Sorting paused: combat.") return end

    ClearCursor()
    local fromBag, fromSlot, toBag, toSlot = self:FindNextMove(sortBank)
    if fromBag then
        local _, _, lockedFrom = GetContainerItemInfo(fromBag, fromSlot)
        local _, _, lockedTo = GetContainerItemInfo(toBag, toSlot)
        if lockedFrom or lockedTo then return end

        PickupContainerItem(fromBag, fromSlot)
        PickupContainerItem(toBag, toSlot)
        ClearCursor()
        timerFrame.elapsed = 0
        timerFrame:Show()
    else
        self:StopPhysicalSort()
        OI:Print("Sorting complete.")
    end
end

function Sorter:FindNextMove(isBank)
    if InCombatLockdown() then return end
    local bagIds = isBank and { -1, 5, 6, 7, 8, 9, 10, 11 } or { 0, 1, 2, 3, 4 }

    local slots = {}
    for _, bag in ipairs(bagIds) do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            table.insert(slots, { bag = bag, slot = slot, slotId = bag * 100 + slot })
        end
    end

    -- Consolidate incomplete stacks
    local incomplete = {}
    for _, s in ipairs(slots) do
        local itemID = GetContainerItemID(s.bag, s.slot)
        if itemID then
            local _, count = GetContainerItemInfo(s.bag, s.slot)
            local maxStack = select(8, GetItemInfo(itemID)) or 1
            if maxStack > 1 and count < maxStack then
                local prev = incomplete[itemID]
                if prev then
                    local prevBag, prevSlot = math.floor(prev / 100), prev % 100
                    if prev < s.slotId then return s.bag, s.slot, prevBag, prevSlot
                    else return prevBag, prevSlot, s.bag, s.slot end
                else
                    incomplete[itemID] = s.slotId
                end
            end
        end
    end

    -- Specialized bag sorting
    local specBags = {}
    local hasSpec = false
    for _, bag in ipairs(bagIds) do
        if bag > 0 then
            local _, bagFamily = GetContainerNumFreeSlots(bag)
            if bagFamily and bagFamily > 0 then
                specBags[bagFamily] = specBags[bagFamily] or {}
                table.insert(specBags[bagFamily], bag)
                hasSpec = true
            end
        end
    end

    if hasSpec then
        for _, s in ipairs(slots) do
            local isGeneral = (s.bag == 0 or s.bag == -1)
            if not isGeneral then
                local _, bagFamily = GetContainerNumFreeSlots(s.bag)
                isGeneral = (not bagFamily or bagFamily == 0)
            end
            if isGeneral then
                local itemLink = GetContainerItemLink(s.bag, s.slot)
                if itemLink then
                    local itemFamily = GetItemFamily(itemLink) or 0
                    if itemFamily > 0 then
                        for family, targets in pairs(specBags) do
                            if band(family, itemFamily) ~= 0 then
                                for _, targetBag in ipairs(targets) do
                                    local freeSlots = {}
                                    GetContainerFreeSlots(targetBag, freeSlots)
                                    if #freeSlots > 0 then
                                        return s.bag, s.slot, targetBag, freeSlots[1]
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- General physical sort
    local generalSlots, generalItems = {}, {}
    for _, s in ipairs(slots) do
        local isGeneral = (s.bag == 0 or s.bag == -1)
        if not isGeneral then
            local _, bagFamily = GetContainerNumFreeSlots(s.bag)
            isGeneral = (not bagFamily or bagFamily == 0)
        end
        if isGeneral then
            table.insert(generalSlots, s)
            local itemLink = GetContainerItemLink(s.bag, s.slot)
            if itemLink then
                local name, _, quality, iLvl = GetItemInfo(itemLink)
                local _, count = GetContainerItemInfo(s.bag, s.slot)
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                table.insert(generalItems, {
                    bag = s.bag, slot = s.slot, link = itemLink,
                    quality = quality or 0, name = name or "",
                    itemLevel = iLvl or 0, stackCount = count or 1,
                    itemID = itemID, slotId = s.slotId,
                })
            end
        end
    end

    local mode = self:GetDefaultMode()
    table.sort(generalItems, function(a, b)
        local pinnedA = a.itemID and OI.Data and OI.Data:IsPinned(a.itemID)
        local pinnedB = b.itemID and OI.Data and OI.Data:IsPinned(b.itemID)
        if pinnedA and not pinnedB then return true end
        if pinnedB and not pinnedA then return false end
        if mode == "quality" and a.quality ~= b.quality then return a.quality > b.quality end
        if mode == "name" and a.name ~= b.name then return a.name < b.name end
        if mode == "ilvl" and a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        return a.slotId < b.slotId
    end)

    for i, expected in ipairs(generalItems) do
        local target = generalSlots[i]
        if expected.slotId ~= target.slotId then
            return expected.bag, expected.slot, target.bag, target.slot
        end
    end

    return nil
end

function Sorter:Init() end

print("|cFF00FF00OmniInventory|r: Sorter loaded")
