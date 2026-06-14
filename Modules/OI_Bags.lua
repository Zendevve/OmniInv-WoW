local addonName, OI = ...
OI.Bags = {}
local Bags = OI.Bags

local BAG_IDS = { 0, 1, 2, 3, 4 }
local BANK_IDS = { -1, 5, 6, 7, 8, 9, 10, 11 }

function Bags:GetBagIDs(isBank)
    return isBank and BANK_IDS or BAG_IDS
end

function Bags:GetAllItems(isBank)
    local items = {}
    local ids = self:GetBagIDs(isBank)
    for _, bagID in ipairs(ids) do
        local numSlots = (bagID == -2 and GetKeyRingSize) and GetKeyRingSize() or (GetContainerNumSlots(bagID) or 0)
        for slot = 1, numSlots do
            local info = OmniC_Container.GetContainerItemInfo(bagID, slot)
            if info then
                info.isNew = OI.Categorizer and OI.Categorizer:IsNewItem(info.itemID)
                table.insert(items, info)
            end
        end
    end
    return items
end

function Bags:GetOfflineItems(charName, isBank)
    if charName == UnitName("player") then return self:GetAllItems(isBank) end
    local char = OI.db.realm[OI.realmName] and OI.db.realm[OI.realmName][charName]
    if not char then return {} end
    local source = isBank and char.bank or char.bags
    if not source then return {} end
    local items = {}
    for _, entry in ipairs(source) do
        if entry.link then
            local name, link, quality, iLevel, reqLevel, itemType, itemSubType, maxStack, equipSlot, texture = GetItemInfo(entry.link)
            local isBound = false
            local bindType = nil
            if OI.API then
                isBound = OI.API:IsItemUnusableLink(entry.link)
            end
            table.insert(items, {
                iconFileID = texture,
                hyperlink = link,
                itemID = tonumber(string.match(entry.link, "item:(%d+)")),
                stackCount = entry.count or 1,
                quality = quality or 0,
                name = name or "Unknown",
                itemType = itemType,
                itemSubType = itemSubType,
                itemLevel = iLevel or 0,
                isBound = isBound,
                bindType = bindType,
                isOffline = true,
                bagID = -1,
                slotID = 0,
            })
        end
    end
    return items
end

function Bags:GetSlotInfo(isBank)
    local ids = self:GetBagIDs(isBank)
    local totalSlots, freeSlots = 0, 0
    for _, bagID in ipairs(ids) do
        if bagID >= 0 then
            local total = GetContainerNumSlots(bagID) or 0
            local free = GetContainerNumFreeSlots(bagID) or 0
            totalSlots = totalSlots + total
            freeSlots = freeSlots + free
        end
    end
    return totalSlots, freeSlots
end

function Bags:SortBags()
    if OI.Sorter then OI.Sorter:PhysicalSort(false) end
end

function Bags:SortBank()
    if OI.Sorter then OI.Sorter:PhysicalSort(true) end
end

function Bags:CountItem(itemID)
    if not itemID then return 0 end
    local count = 0
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local id = GetContainerItemID(bagID, slot)
            if id == itemID then
                local _, qty = GetContainerItemInfo(bagID, slot)
                count = count + (qty or 1)
            end
        end
    end
    return count
end

function Bags:FindItem(itemID)
    if not itemID then return nil end
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local id = GetContainerItemID(bagID, slot)
            if id == itemID then return bagID, slot end
        end
    end
    return nil
end

function Bags:Init() end

print("|cFF00FF00OmniInventory|r: Bags loaded")
