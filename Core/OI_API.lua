-- =============================================================================
-- OmniInventory API Shim
-- =============================================================================
-- Bridges 3.3.5a APIs to modern table-based returns.
-- =============================================================================

local addonName, OI = ...

OI.API = {}
local API = OI.API

local clientVersion = select(4, GetBuildInfo()) or 30300
API.isWotLK = clientVersion < 40000
API.isRetail = clientVersion >= 100000

-- =============================================================================
-- Tooltip Scanner
-- =============================================================================

local scanningTooltip = CreateFrame("GameTooltip", "OIScanningTooltip", nil, "GameTooltipTemplate")
scanningTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local SOULBOUND_TEXT = ITEM_SOULBOUND or "Soulbound"
local BOE_TEXT = ITEM_BIND_ON_EQUIP or "Binds when equipped"
local BOP_TEXT = ITEM_BIND_ON_PICKUP or "Binds when picked up"
local BOA_TEXT = ITEM_BIND_TO_ACCOUNT or "Binds to account"

local function ScanTooltipForBinding(bag, slot)
    scanningTooltip:ClearLines()
    scanningTooltip:SetBagItem(bag, slot)
    for i = 2, math.min(5, scanningTooltip:NumLines()) do
        local textFrame = _G["OIScanningTooltipTextLeft" .. i]
        if textFrame then
            local line = textFrame:GetText()
            if line then
                if line == SOULBOUND_TEXT then return true, "Soulbound"
                elseif line == BOE_TEXT then return false, "BoE"
                elseif line == BOP_TEXT then return false, "BoP"
                elseif line == BOA_TEXT then return true, "BoA" end
            end
        end
    end
    return false, nil
end

-- =============================================================================
-- OmniC_Container (C_Container Polyfill)
-- =============================================================================

OmniC_Container = {}

function OmniC_Container.GetContainerItemInfo(bagID, slotID)
    local texture, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bagID, slotID)
    if not texture then return nil end

    local itemID = nil
    if itemLink then itemID = tonumber(string.match(itemLink, "item:(%d+)")) end

    local isBound, bindType = ScanTooltipForBinding(bagID, slotID)

    if (not quality or quality < 0) and itemLink then
        local _, _, itemQuality = GetItemInfo(itemLink)
        quality = itemQuality
    end

    return {
        iconFileID = texture,
        itemID = itemID,
        hyperlink = itemLink,
        stackCount = itemCount or 1,
        isLocked = locked or false,
        isReadable = readable or false,
        hasLoot = lootable or false,
        isBound = isBound,
        bindType = bindType,
        quality = quality or 1,
        bagID = bagID,
        slotID = slotID,
    }
end

function OmniC_Container.GetContainerNumSlots(bagID)
    if bagID == -2 then return GetKeyRingSize() or 0 end
    return GetContainerNumSlots(bagID) or 0
end

function OmniC_Container.GetContainerFreeSlots(bagID)
    local numFreeSlots, bagType = GetContainerNumFreeSlots(bagID)
    return numFreeSlots or 0, bagType or 0
end

function OmniC_Container.GetContainerItems(bagID)
    local items = {}
    for slotID = 1, OmniC_Container.GetContainerNumSlots(bagID) do
        local info = OmniC_Container.GetContainerItemInfo(bagID, slotID)
        if info then table.insert(items, info) end
    end
    return items
end

function OmniC_Container.GetAllBagItems()
    local items = {}
    for bagID = 0, 4 do
        for _, item in ipairs(OmniC_Container.GetContainerItems(bagID)) do
            table.insert(items, item)
        end
    end
    return items
end

function OmniC_Container.GetAllBankItems()
    local items = {}
    for _, item in ipairs(OmniC_Container.GetContainerItems(-1)) do
        table.insert(items, item)
    end
    for bagID = 5, 11 do
        for _, item in ipairs(OmniC_Container.GetContainerItems(bagID)) do
            table.insert(items, item)
        end
    end
    return items
end

function OmniC_Container.GetAllKeyringItems()
    return OmniC_Container.GetContainerItems(-2)
end

-- =============================================================================
-- Extended Item Info
-- =============================================================================

function API:GetExtendedItemInfo(itemLink)
    if not itemLink then return nil end
    local name, link, quality, iLevel, reqLevel, class, subclass,
          maxStack, equipSlot, texture, vendorPrice = GetItemInfo(itemLink)
    if not name then return nil end
    return {
        name = name, link = link, quality = quality or 0,
        itemLevel = iLevel or 0, requiredLevel = reqLevel or 0,
        itemType = class, itemSubType = subclass,
        maxStackSize = maxStack or 1, equipSlot = equipSlot,
        iconFileID = texture, vendorPrice = vendorPrice or 0,
    }
end

-- =============================================================================
-- Usability Scanner
-- =============================================================================

function API:IsItemUnusable(bag, slot)
    if not bag or not slot then return false end
    scanningTooltip:ClearLines()
    scanningTooltip:SetBagItem(bag, slot)
    for i = 1, scanningTooltip:NumLines() do
        local textFrame = _G["OIScanningTooltipTextLeft" .. i]
        if textFrame then
            local r, g, b = textFrame:GetTextColor()
            if r > 0.9 and g < 0.2 and b < 0.2 then return true end
        end
    end
    return false
end

function API:IsItemUnusableLink(link)
    if not link then return false end
    scanningTooltip:ClearLines()
    scanningTooltip:SetHyperlink(link)
    for i = 1, scanningTooltip:NumLines() do
        local textFrame = _G["OIScanningTooltipTextLeft" .. i]
        if textFrame then
            local r, g, b = textFrame:GetTextColor()
            if r > 0.9 and g < 0.2 and b < 0.2 then return true end
        end
    end
    return false
end

-- =============================================================================
-- Tooltip Text Scanning
-- =============================================================================

function API:TooltipContains(bag, slot, searchText)
    if not bag or not slot or not searchText then return false end
    scanningTooltip:ClearLines()
    scanningTooltip:SetBagItem(bag, slot)
    local lowerSearch = string.lower(searchText)
    for i = 1, scanningTooltip:NumLines() do
        local textFrame = _G["OIScanningTooltipTextLeft" .. i]
        local line = textFrame and textFrame:GetText()
        if line and string.find(string.lower(line), lowerSearch, 1, true) then return true end
    end
    return false
end

function API:TooltipLinkContains(link, searchText)
    if not link or not searchText then return false end
    scanningTooltip:ClearLines()
    scanningTooltip:SetHyperlink(link)
    local lowerSearch = string.lower(searchText)
    for i = 1, scanningTooltip:NumLines() do
        local textFrame = _G["OIScanningTooltipTextLeft" .. i]
        local line = textFrame and textFrame:GetText()
        if line and string.find(string.lower(line), lowerSearch, 1, true) then return true end
    end
    return false
end

print("|cFF00FF00OmniInventory|r: API loaded (" .. (API.isWotLK and "WotLK" or "Retail") .. ")")
