-- =============================================================================
-- OmniInventory Virtual Stacks Engine
-- =============================================================================
-- Purpose: Combine multiple partial stacks of the same item across bags/bank
-- into a single visual slot with total count (ArkInventory-style).
-- =============================================================================

local addonName, Omni = ...

Omni.VirtualStacks = {}
local VirtualStacks = Omni.VirtualStacks

-- =============================================================================
-- Constants
-- =============================================================================

local MAX_SOURCES_IN_TOOLTIP = 3
local BAG_ORDER = {0, 1, 2, 3, 4}
local BANK_BAG_ORDER = {-1, 5, 6, 7, 8, 9, 10, 11}

-- =============================================================================
-- Override Check
-- =============================================================================

--- Check if an item should be virtually stacked
---@param itemID number|nil
---@return boolean
function VirtualStacks:ShouldCombine(itemID)
    if not itemID then
        return false
    end

    -- Check per-item override
    if OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.virtualStackOverrides then
        if OmniInventoryDB.char.virtualStackOverrides[itemID] == true then
            return false
        end
    end

    return true
end

-- =============================================================================
-- Source Slot Ordering
-- =============================================================================

--- Order source slots by consumption priority
---@param sources table Array of {bagID, slotID, count}
---@param isBankMode boolean
---@return table ordered Ordered source slots
local function OrderSourceSlots(sources, isBankMode)
    if not sources or #sources == 0 then
        return {}
    end

    -- Build priority map
    local priorityMap = {}
    if isBankMode then
        -- Bank first, then bags
        for i, bagID in ipairs(BANK_BAG_ORDER) do
            priorityMap[bagID] = i
        end
        for i, bagID in ipairs(BAG_ORDER) do
            priorityMap[bagID] = i + #BANK_BAG_ORDER
        end
    else
        -- Bags first, then bank
        for i, bagID in ipairs(BAG_ORDER) do
            priorityMap[bagID] = i
        end
        for i, bagID in ipairs(BANK_BAG_ORDER) do
            priorityMap[bagID] = i + #BAG_ORDER
        end
    end

    -- Sort by priority, then by slot ID for deterministic ordering
    table.sort(sources, function(a, b)
        local prioA = priorityMap[a.bagID] or 999
        local prioB = priorityMap[b.bagID] or 999
        if prioA ~= prioB then
            return prioA < prioB
        end
        return a.slotID < b.slotID
    end)

    return sources
end

-- =============================================================================
-- Virtual Item Creation
-- =============================================================================

--- Create a virtual item from a group of real items
---@param group table Array of real item tables with same itemID
---@param isBankMode boolean
---@return table virtualItem
local function CreateVirtualItem(group, isBankMode)
    local first = group[1]
    local totalCount = 0
    local sources = {}

    for _, item in ipairs(group) do
        totalCount = totalCount + (item.stackCount or 1)
        table.insert(sources, {
            bagID = item.bagID,
            slotID = item.slotID,
            count = item.stackCount or 1,
        })
    end

    sources = OrderSourceSlots(sources, isBankMode)

    -- Build virtual item from first real item, preserving key fields
    local virtual = {
        -- Core identification
        itemID = first.itemID,
        hyperlink = first.hyperlink,
        iconFileID = first.iconFileID,

        -- Virtual stack properties
        stackCount = totalCount,
        isVirtual = true,
        sourceSlots = sources,

        -- Preserve metadata from first item
        quality = first.quality,
        itemType = first.itemType,
        itemSubType = first.itemSubType,
        itemLevel = first.itemLevel,
        equipSlot = first.equipSlot,
        vendorPrice = first.vendorPrice,
        isBound = first.isBound,
        bindType = first.bindType,
        isLocked = first.isLocked,
        isReadable = first.isReadable,
        hasLoot = first.hasLoot,

        -- Use first source for tooltip fallback
        bagID = sources[1] and sources[1].bagID or first.bagID,
        slotID = sources[1] and sources[1].slotID or first.slotID,
    }

    return virtual
end

-- =============================================================================
-- Main Combiner
-- =============================================================================

--- Combine partial stacks of identical items into virtual stacks
---@param items table Array of real item tables
---@param isBankMode boolean Whether viewing bank (affects consumption priority)
---@return table combined Array of items (virtual + pass-through)
function VirtualStacks:CombineItems(items, isBankMode)
    if not items or #items == 0 then
        return items
    end

    -- Group items by itemID
    local groups = {}  -- { [itemID] = { item1, item2, ... } }

    for _, item in ipairs(items) do
        local itemID = item.itemID
        if itemID and self:ShouldCombine(itemID) then
            groups[itemID] = groups[itemID] or {}
            table.insert(groups[itemID], item)
        else
            -- Item with no ID or override — keep in pass-through list
            groups[itemID or "__passthrough_" .. tostring(#items)] = { item }
        end
    end

    -- Build combined result
    local combined = {}

    for itemID, group in pairs(groups) do
        if #group > 1 then
            -- Multiple real slots — create virtual item
            local virtual = CreateVirtualItem(group, isBankMode)
            table.insert(combined, virtual)
        else
            -- Single item — pass through unchanged
            table.insert(combined, group[1])
        end
    end

    return combined
end

-- =============================================================================
-- Consumption Resolution
-- =============================================================================

--- Resolve a virtual item to the real bag/slot for consumption
---@param virtualItem table
---@return number|nil bagID
---@return number|nil slotID
function VirtualStacks:GetConsumptionSlot(virtualItem)
    if not virtualItem or not virtualItem.isVirtual then
        return virtualItem and virtualItem.bagID, virtualItem and virtualItem.slotID
    end

    local sources = virtualItem.sourceSlots
    if not sources or #sources == 0 then
        return nil, nil
    end

    -- Return first source slot (highest priority)
    local first = sources[1]
    return first.bagID, first.slotID
end

-- =============================================================================
-- Tooltip Text Generation
-- =============================================================================

--- Generate tooltip lines for a virtual stack
---@param virtualItem table
---@return table lines Array of tooltip text lines
function VirtualStacks:GetTooltipText(virtualItem)
    if not virtualItem or not virtualItem.isVirtual then
        return {}
    end

    local sources = virtualItem.sourceSlots
    if not sources or #sources == 0 then
        return {}
    end

    local lines = {}
    local sourceCount = #sources

    -- Indicator line
    table.insert(lines, string.format("(Virtual stack: %d source%s)",
        sourceCount, sourceCount == 1 and "" or "s"))

    -- Total count line with breakdown
    local breakdown = {}
    for i = 1, math.min(MAX_SOURCES_IN_TOOLTIP, sourceCount) do
        local src = sources[i]
        local locName
        if src.bagID == -1 then
            locName = "Bank"
        elseif src.bagID == 0 then
            locName = "Backpack"
        elseif src.bagID >= 1 and src.bagID <= 4 then
            locName = string.format("Bag %d", src.bagID)
        elseif src.bagID >= 5 and src.bagID <= 11 then
            locName = string.format("Bank Bag %d", src.bagID - 4)
        else
            locName = string.format("Bag %d", src.bagID)
        end
        table.insert(breakdown, string.format("%s (%d)", locName, src.count))
    end

    local breakdownText = table.concat(breakdown, ", ")
    if sourceCount > MAX_SOURCES_IN_TOOLTIP then
        local remaining = sourceCount - MAX_SOURCES_IN_TOOLTIP
        breakdownText = breakdownText .. string.format(", and %d more", remaining)
    end

    table.insert(lines, string.format("%d total: %s", virtualItem.stackCount or 0, breakdownText))

    return lines
end

-- =============================================================================
-- Initialization
-- =============================================================================

print("|cFF00FF00OmniInventory|r: Virtual Stacks Engine loaded")
