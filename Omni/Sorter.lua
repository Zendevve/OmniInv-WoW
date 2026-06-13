-- =============================================================================
-- OmniInventory Stable Merge Sort
-- =============================================================================
-- Purpose: Deterministic, stable sorting algorithm that eliminates
-- "dancing items" problem. Same inputs always produce same outputs.
-- =============================================================================

local addonName, Omni = ...

Omni.Sorter = {}
local Sorter = Omni.Sorter

-- Bitwise AND fallback for Lua versions without the bit library
local band = (bit and bit.band) or function(a, b)
    local result = 0
    local bitVal = 1
    while a > 0 or b > 0 do
        if (a % 2 == 1) and (b % 2 == 1) then
            result = result + bitVal
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bitVal = bitVal * 2
    end
    return result
end

-- =============================================================================
-- Merge Sort Implementation (Stable)
-- =============================================================================

-- Merge two sorted sub-arrays into one
local function Merge(arr, left, mid, right, comparator)
    local n1 = mid - left + 1
    local n2 = right - mid

    -- Create temp arrays
    local L = {}
    local R = {}

    for i = 1, n1 do
        L[i] = arr[left + i - 1]
    end
    for j = 1, n2 do
        R[j] = arr[mid + j]
    end

    -- Merge temp arrays back into arr
    local i = 1
    local j = 1
    local k = left

    while i <= n1 and j <= n2 do
        -- Use <= for stability (left element wins on tie)
        if comparator(L[i], R[j]) or not comparator(R[j], L[i]) then
            arr[k] = L[i]
            i = i + 1
        else
            arr[k] = R[j]
            j = j + 1
        end
        k = k + 1
    end

    -- Copy remaining elements
    while i <= n1 do
        arr[k] = L[i]
        i = i + 1
        k = k + 1
    end

    while j <= n2 do
        arr[k] = R[j]
        j = j + 1
        k = k + 1
    end
end

-- Recursive merge sort
local function MergeSort(arr, left, right, comparator)
    if left < right then
        local mid = math.floor((left + right) / 2)

        MergeSort(arr, left, mid, comparator)
        MergeSort(arr, mid + 1, right, comparator)
        Merge(arr, left, mid, right, comparator)
    end
end

-- =============================================================================
-- Comparator Functions
-- =============================================================================

-- Get category priority for sorting
local function GetCategoryPriority(item)
    if not item or not item.category then
        return 99
    end

    if Omni.Categorizer then
        local catInfo = Omni.Categorizer:GetCategoryInfo(item.category)
        return catInfo and catInfo.priority or 99
    end

    return 99
end

-- Get item name (cached from GetItemInfo)
local function GetItemName(item)
    if not item or not item.hyperlink then
        return "zzz"  -- Sort unknown items last
    end

    local name = GetItemInfo(item.hyperlink)
    return name or "zzz"
end

-- Get item level
local function GetItemLevel(item)
    if not item or not item.hyperlink then
        return 0
    end

    local _, _, _, iLvl = GetItemInfo(item.hyperlink)
    return iLvl or 0
end

-- =============================================================================
-- Comparator Chain (Multi-tier)
-- =============================================================================

-- Returns true if a should come before b
local function DefaultComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    -- 0. Pinned/Favorite items first
    local pinnedA = a.itemID and Omni.Data and Omni.Data:IsPinned(a.itemID)
    local pinnedB = b.itemID and Omni.Data and Omni.Data:IsPinned(b.itemID)
    if pinnedA and not pinnedB then return true end
    if pinnedB and not pinnedA then return false end

    -- 1. Category Priority (lower number = higher priority)
    local catA = GetCategoryPriority(a)
    local catB = GetCategoryPriority(b)
    if catA ~= catB then
        return catA < catB
    end

    -- 2. Quality (Higher first: Purple > Blue > Green)
    local qualA = a.quality or 0
    local qualB = b.quality or 0
    if qualA ~= qualB then
        return qualA > qualB
    end

    -- 3. Item Level (Higher first)
    local ilvlA = GetItemLevel(a)
    local ilvlB = GetItemLevel(b)
    if ilvlA ~= ilvlB then
        return ilvlA > ilvlB
    end

    -- 4. Name (Alphabetical)
    local nameA = GetItemName(a)
    local nameB = GetItemName(b)
    if nameA ~= nameB then
        return nameA < nameB
    end

    -- 5. Stack Count (Higher first)
    local stackA = a.stackCount or 1
    local stackB = b.stackCount or 1
    if stackA ~= stackB then
        return stackA > stackB
    end

    -- 6. Fallback: Bag/Slot order (for absolute stability)
    local posA = ((a.bagID or 0) * 100) + (a.slotID or 0)
    local posB = ((b.bagID or 0) * 100) + (b.slotID or 0)
    return posA < posB
end

-- Quality-only comparator
local function QualityComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    local qualA = a.quality or 0
    local qualB = b.quality or 0
    if qualA ~= qualB then
        return qualA > qualB
    end

    return DefaultComparator(a, b)
end

-- Name-only comparator
local function NameComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    local nameA = GetItemName(a)
    local nameB = GetItemName(b)
    if nameA ~= nameB then
        return nameA < nameB
    end

    return DefaultComparator(a, b)
end

-- iLvl-only comparator
local function ILvlComparator(a, b)
    if not a and not b then return false end
    if not a then return false end
    if not b then return true end

    local ilvlA = GetItemLevel(a)
    local ilvlB = GetItemLevel(b)
    if ilvlA ~= ilvlB then
        return ilvlA > ilvlB
    end

    return DefaultComparator(a, b)
end

-- =============================================================================
-- Public API
-- =============================================================================

local COMPARATORS = {
    category = DefaultComparator,
    quality = QualityComparator,
    name = NameComparator,
    ilvl = ILvlComparator,
}

--- Sort items using stable merge-sort
---@param items table Array of item info tables
---@param mode string Optional sort mode: "category", "quality", "name", "ilvl"
---@return table Sorted array (new table)
function Sorter:Sort(items, mode)
    if not items or #items == 0 then
        return {}
    end

    -- Copy array (don't modify original)
    local sorted = {}
    for i, item in ipairs(items) do
        sorted[i] = item
    end

    -- Get comparator
    local comparator = COMPARATORS[mode] or DefaultComparator

    -- Apply stable merge sort
    MergeSort(sorted, 1, #sorted, comparator)

    return sorted
end

--- Sort items within their categories
---@param categorizedItems table { categoryName = { items } }
---@return table Same structure with sorted items
function Sorter:SortCategorized(categorizedItems)
    local result = {}

    for category, items in pairs(categorizedItems) do
        result[category] = self:Sort(items, "category")
    end

    return result
end

--- Get available sort modes
---@return table Array of mode names
function Sorter:GetModes()
    return { "category", "quality", "name", "ilvl" }
end

--- Get current default sort mode
---@return string
function Sorter:GetDefaultMode()
    if OmniInventoryDB and OmniInventoryDB.global then
        return OmniInventoryDB.global.sortMode or "category"
    end
    return "category"
end

--- Set default sort mode
---@param mode string
function Sorter:SetDefaultMode(mode)
    if COMPARATORS[mode] then
        OmniInventoryDB = OmniInventoryDB or {}
        OmniInventoryDB.global = OmniInventoryDB.global or {}
        OmniInventoryDB.global.sortMode = mode
    end
end

-- =============================================================================
-- Physical Bag Sorting State Machine
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
        if Sorter:IsPhysicalSorting() then
            Sorter:ProcessNextPhysicalMove()
        end
    end
end)

function Sorter:IsPhysicalSorting()
    return isSorting
end

function Sorter:PhysicalSort(isBank)
    if isSorting then return end
    if InCombatLockdown() then
        print("|cFF00FF00OmniInventory|r: Cannot sort bags in combat.")
        return
    end

    isSorting = true
    sortBank = isBank or false
    print("|cFF00FF00OmniInventory|r: Sorting bags...")

    -- Perform the first move
    self:ProcessNextPhysicalMove()
end

function Sorter:StopPhysicalSort()
    isSorting = false
    timerFrame:Hide()
    if Omni.Frame then
        Omni.Frame:UpdateLayout()
    end
end

function Sorter:ProcessNextPhysicalMove()
    if not isSorting then return end

    if InCombatLockdown() then
        self:StopPhysicalSort()
        print("|cFF00FF00OmniInventory|r: Sorting paused due to combat.")
        return
    end

    -- Clear cursor before picking up
    ClearCursor()

    local fromBag, fromSlot, toBag, toSlot = self:FindNextMove(sortBank)
    if fromBag and fromSlot and toBag and toSlot then
        -- Safety check: ensure slots are not locked
        local _, _, lockedFrom = GetContainerItemInfo(fromBag, fromSlot)
        local _, _, lockedTo = GetContainerItemInfo(toBag, toSlot)
        if lockedFrom or lockedTo then
            -- Slots are currently locked by the server; wait for BAG_UPDATE
            return
        end

        -- Execute move: pickup from slot, drop in target slot
        PickupContainerItem(fromBag, fromSlot)
        PickupContainerItem(toBag, toSlot)
        ClearCursor()

        -- Set a safety timeout in case BAG_UPDATE is missed
        timerFrame.elapsed = 0
        timerFrame:Show()
    else
        -- No more moves! Sorting complete.
        self:StopPhysicalSort()
        print("|cFF00FF00OmniInventory|r: Sorting complete.")
    end
end

local function GetBagsSlots(bagIds)
    local slots = {}
    for _, bag in ipairs(bagIds) do
        local numSlots = GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            table.insert(slots, { bag = bag, slot = slot, slotId = bag * 100 + slot })
        end
    end
    return slots
end

function Sorter:FindNextMove(isBank)
    if InCombatLockdown() then return end

    local bagIds = isBank and { -1, 5, 6, 7, 8, 9, 10, 11 } or { 0, 1, 2, 3, 4 }
    local slots = GetBagsSlots(bagIds)

    -- Step 1: Consolidate incomplete stacks
    local incomplete = {}
    for _, slotInfo in ipairs(slots) do
        local bag, slot = slotInfo.bag, slotInfo.slot
        local itemID = GetContainerItemID(bag, slot)
        if itemID then
            local _, count = GetContainerItemInfo(bag, slot)
            local maxStack = select(8, GetItemInfo(itemID)) or 1
            if maxStack > 1 and count < maxStack then
                local prevSlotId = incomplete[itemID]
                if prevSlotId then
                    local prevBag, prevSlot = math.floor(prevSlotId / 100), prevSlotId % 100
                    if prevSlotId < slotInfo.slotId then
                        return bag, slot, prevBag, prevSlot
                    else
                        return prevBag, prevSlot, bag, slot
                    end
                else
                    incomplete[itemID] = slotInfo.slotId
                end
            end
        end
    end

    -- Step 2: Specialized bag sorting
    local specBags = {}
    local hasSpecBags = false
    for _, bag in ipairs(bagIds) do
        if bag > 0 then
            local _, bagFamily = GetContainerNumFreeSlots(bag)
            if bagFamily and bagFamily > 0 then
                specBags[bagFamily] = specBags[bagFamily] or {}
                table.insert(specBags[bagFamily], bag)
                hasSpecBags = true
            end
        end
    end

    if hasSpecBags then
        for _, slotInfo in ipairs(slots) do
            local bag, slot = slotInfo.bag, slotInfo.slot
            local isGeneralBag = (bag == 0 or bag == -1)
            if not isGeneralBag then
                local _, bagFamily = GetContainerNumFreeSlots(bag)
                isGeneralBag = (not bagFamily or bagFamily == 0)
            end

            if isGeneralBag then
                local itemLink = GetContainerItemLink(bag, slot)
                if itemLink then
                    local itemFamily = GetItemFamily(itemLink) or 0
                    if itemFamily > 0 then
                        for family, targetBags in pairs(specBags) do
                            if band(family, itemFamily) ~= 0 then
                                for _, targetBag in ipairs(targetBags) do
                                    local freeSlots = {}
                                    GetContainerFreeSlots(targetBag, freeSlots)
                                    if #freeSlots > 0 then
                                        return bag, slot, targetBag, freeSlots[1]
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Step 3: General physical sorting
    local generalSlots = {}
    local generalItems = {}
    for _, slotInfo in ipairs(slots) do
        local bag = slotInfo.bag
        local isGeneral = (bag == 0 or bag == -1)
        if not isGeneral then
            local _, bagFamily = GetContainerNumFreeSlots(bag)
            isGeneral = (not bagFamily or bagFamily == 0)
        end

        if isGeneral then
            table.insert(generalSlots, slotInfo)
            local itemLink = GetContainerItemLink(bag, slotInfo.slot)
            if itemLink then
                local name, _, quality, iLvl = GetItemInfo(itemLink)
                local _, count = GetContainerItemInfo(bag, slotInfo.slot)
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))

                table.insert(generalItems, {
                    bag = bag,
                    slot = slotInfo.slot,
                    link = itemLink,
                    quality = quality or 0,
                    name = name or "",
                    itemLevel = iLvl or 0,
                    stackCount = count or 1,
                    itemID = itemID,
                    slotId = slotInfo.slotId,
                })
            end
        end
    end

    local mode = Sorter:GetDefaultMode()
    table.sort(generalItems, function(a, b)
        local pinnedA = a.itemID and Omni.Data and Omni.Data:IsPinned(a.itemID)
        local pinnedB = b.itemID and Omni.Data and Omni.Data:IsPinned(b.itemID)
        if pinnedA and not pinnedB then return true end
        if pinnedB and not pinnedA then return false end

        if mode == "quality" then
            if a.quality ~= b.quality then return a.quality > b.quality end
        elseif mode == "name" then
            if a.name ~= b.name then return a.name < b.name end
        elseif mode == "ilvl" then
            if a.itemLevel ~= b.itemLevel then return a.itemLevel > b.itemLevel end
        end

        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        return a.slotId < b.slotId
    end)

    for i, expectedItem in ipairs(generalItems) do
        local targetSlot = generalSlots[i]
        if expectedItem.slotId ~= targetSlot.slotId then
            return expectedItem.bag, expectedItem.slot, targetSlot.bag, targetSlot.slot
        end
    end

    return nil
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Sorter:Init()
    -- Maintain consistency
end

print("|cFF00FF00OmniInventory|r: Sorter loaded (stable merge-sort)")
