local addonName, OI = ...
OI.Keys = {}
local Keys = OI.Keys

function Keys:IsOpen()
    return OI.Frame and OI.Frame:GetMode() == "keys"
end

function Keys:GetAllItems()
    local items = {}
    local keyringSize = GetKeyRingSize and GetKeyRingSize() or 0
    for slot = 1, keyringSize do
        local info = OmniC_Container.GetContainerItemInfo(-2, slot)
        if info then table.insert(items, info) end
    end
    return items
end

function Keys:GetSlotInfo()
    local totalSlots = GetKeyRingSize and GetKeyRingSize() or 0
    local freeSlots = 0
    for slot = 1, totalSlots do
        if not GetContainerItemInfo(-2, slot) then freeSlots = freeSlots + 1 end
    end
    return totalSlots, freeSlots
end

function Keys:CountItem(itemID)
    if not itemID then return 0 end
    local count = 0
    local keyringSize = GetKeyRingSize and GetKeyRingSize() or 0
    for slot = 1, keyringSize do
        local id = GetContainerItemID(-2, slot)
        if id == itemID then
            local _, qty = GetContainerItemInfo(-2, slot)
            count = count + (qty or 1)
        end
    end
    return count
end

function Keys:Init() end

print("|cFF00FF00OmniInventory|r: Keys loaded")
