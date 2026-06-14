local addonName, OI = ...
OI.Bank = {}
local Bank = OI.Bank

local BANK_BAG_IDS = { -1, 5, 6, 7, 8, 9, 10, 11 }

function Bank:IsOpen()
    return OI.Frame and OI.Frame:IsBankOpen() or false
end

function Bank:GetAllItems()
    if not self:IsOpen() then
        return OI.Bags and OI.Bags:GetOfflineItems(OI.playerName, true) or {}
    end
    local items = {}
    for _, bagID in ipairs(BANK_BAG_IDS) do
        local numSlots = GetContainerNumSlots(bagID) or 0
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

function Bank:GetSlotInfo()
    local totalSlots, freeSlots = 0, 0
    for _, bagID in ipairs(BANK_BAG_IDS) do
        local total = GetContainerNumSlots(bagID) or 0
        local free = GetContainerNumFreeSlots(bagID) or 0
        totalSlots = totalSlots + total
        freeSlots = freeSlots + free
    end
    return totalSlots, freeSlots
end

function Bank:GetNumPurchased()
    return GetNumBankSlots() or 0
end

function Bank:GetMaxPurchased()
    return NUM_BANKGENERIC_SLOTS or 28
end

function Bank:PurchaseSlot()
    local cost = GetBankSlotCost(self:GetNumPurchased())
    StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
end

function Bank:SortBags()
    if OI.Sorter then OI.Sorter:PhysicalSort(true) end
end

function Bank:Init()
    OI:RegisterEvent("BANK_OPENED", "OnBankOpened")
    OI:RegisterEvent("BANK_CLOSED", "OnBankClosed")
end

function Bank:OnBankOpened()
    if OI.Frame then OI.Frame:SetBankOpen(true) end
    if OI.Data then OI.Data:SaveBankItems() end
    if OI.SendMessage then OI:SendMessage("TooltipUpdated") end
end

function Bank:OnBankClosed()
    if OI.Frame then OI.Frame:SetBankOpen(false) end
    if OI.SendMessage then OI:SendMessage("TooltipUpdated") end
end

print("|cFF00FF00OmniInventory|r: Bank loaded")
