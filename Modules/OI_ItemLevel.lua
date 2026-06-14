local addonName, OI = ...
OI.ItemLevel = {}
local ItemLevel = OI.ItemLevel

local function GetBagItemLink(bag, slot)
    if bag == -2 then
        local link = GetContainerItemLink(-2, slot)
        return link
    end
    local link = GetContainerItemLink(bag, slot)
    return link
end

function ItemLevel:ScanBagItems(bagID, buttonFunc)
    if not OI.db.global.showItemLevel then return end
    if not buttonFunc then return end
    local numSlots = GetContainerNumSlots(bagID) or 0
    for slot = 1, numSlots do
        local link = GetContainerItemLink(bagID, slot)
        if link then
            local _, _, quality, iLevel, _, _, _, _, equipSlot = GetItemInfo(link)
            if iLevel and iLevel > 0 and quality and quality >= 2 then
                local isWeapon = equipSlot and (string.find(equipSlot, "INVTYPE_WEAPON") or string.find(equipSlot, "INVTYPE_2HWEAPON"))
                local isArmor = equipSlot and string.find(equipSlot, "INVTYPE Armor")
                if isWeapon or isArmor then
                    buttonFunc(bagID, slot, iLevel)
                end
            end
        end
    end
end

function ItemLevel:GetItemLevel(bag, slot)
    local link = GetBagItemLink(bag, slot)
    if not link then return 0 end
    local _, _, _, iLevel = GetItemInfo(link)
    return iLevel or 0
end

function ItemLevel:IsUpgrade(bag, slot)
    if PawnIsContainerItemAnUpgrade then
        local ok, result = pcall(PawnIsContainerItemAnUpgrade, bag, slot)
        return ok and result or false
    end
    return false
end

function ItemLevel:GetUpgradeStatus(bag, slot)
    local isUpgrade = self:IsUpgrade(bag, slot)
    if isUpgrade then return "upgrade" end
    return nil
end

function ItemLevel:Init() end

print("|cFF00FF00OmniInventory|r: ItemLevel loaded")
