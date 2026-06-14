local addonName, OI = ...
OI.Junk = {}
local Junk = OI.Junk

function Junk:IsJunk(itemInfo)
    if not itemInfo then return false end
    if itemInfo.quality and itemInfo.quality == 0 then return true end
    return false
end

function Junk:GetJunkItems()
    local junkItems = {}
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) or 0 do
            local info = OmniC_Container.GetContainerItemInfo(bagID, slot)
            if info and self:IsJunk(info) then
                table.insert(junkItems, info)
            end
        end
    end
    return junkItems
end

function Junk:GetTotalJunkValue()
    local total = 0
    for _, item in ipairs(self:GetJunkItems()) do
        if item.hyperlink then
            local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(item.hyperlink)
            if vendorPrice then total = total + (vendorPrice * (item.stackCount or 1)) end
        end
    end
    return total
end

function Junk:SellAll()
    if not IsMerchantOpen() then return end
    local items = self:GetJunkItems()
    if #items == 0 then return end

    local sold = 0
    for _, item in ipairs(items) do
        if item.bagID and item.slotID then
            for i = 1, (item.stackCount or 1) do
                UseContainerItem(item.bagID, item.slotID)
                sold = sold + 1
                break
            end
        end
    end
    if sold > 0 then OI:Print("Sold " .. sold .. " junk item(s).") end
end

function Junk:SellAllWithConfirmation()
    if not IsMerchantOpen() then
        OI:Print("Must be at a vendor.")
        return
    end
    local junkItems = self:GetJunkItems()
    if #junkItems == 0 then
        OI:Print("No junk to sell.")
        return
    end

    local totalValue = self:GetTotalJunkValue()
    StaticPopup_Show("OMNIINVENTORY_SELL_JUNK", OI.Utils:FormatMoney(totalValue), #junkItems)
end

function Junk:Init()
    StaticPopupDialogs["OMNIINVENTORY_SELL_JUNK"] = {
        text = "Sell %d junk items for %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function() Junk:SellAll() end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
    }
end

print("|cFF00FF00OmniInventory|r: Junk loaded")
