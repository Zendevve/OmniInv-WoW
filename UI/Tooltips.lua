-- =============================================================================
-- OmniInventory Cross-Character Tooltips Hook
-- =============================================================================
-- Purpose: Hooks item tooltips to show how many of that item are held
-- by other characters on the current realm (bags vs bank).
-- =============================================================================

local addonName, Omni = ...

local currentPlayer = UnitName("player")
local SILVER = "|cffc7c7cf%s|r"
local GOLD = "|cffffd700%s|r"
local WHITE = "|cffffffff%s|r"

-- Helper to get color code for a character class
local function GetClassColorCode(class)
    local color = class and RAID_CLASS_COLORS[class]
    if color then
        return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return "|cff00ff9a" -- Teal default
end

-- Counts and formats the quantities of an item ID for a given character data
local function GetCharacterItemCounts(charData, targetItemID)
    local bagsCount = 0
    local bankCount = 0
    local keyringCount = 0

    -- 1. Scan bags
    if charData.bags then
        for _, item in ipairs(charData.bags) do
            if item.link then
                local itemID = tonumber(string.match(item.link, "item:(%d+)"))
                if itemID == targetItemID then
                    bagsCount = bagsCount + (item.count or 1)
                end
            end
        end
    end

    -- 2. Scan bank
    if charData.bank then
        for _, item in ipairs(charData.bank) do
            if item.link then
                local itemID = tonumber(string.match(item.link, "item:(%d+)"))
                if itemID == targetItemID then
                    bankCount = bankCount + (item.count or 1)
                end
            end
        end
    end

    -- 3. Scan keyring
    if charData.keyring then
        for _, item in ipairs(charData.keyring) do
            if item.link then
                local itemID = tonumber(string.match(item.link, "item:(%d+)"))
                if itemID == targetItemID then
                    keyringCount = keyringCount + (item.count or 1)
                end
            end
        end
    end

    return bagsCount, bankCount, keyringCount
end

-- Appends owner counts to the tooltip
local function AddOwnerCounts(tooltip, itemLink)
    if not itemLink then return end
    local targetItemID = tonumber(string.match(itemLink, "item:(%d+)"))
    if not targetItemID then return end

    local realmName = GetRealmName()
    local realm = OmniInventoryDB and OmniInventoryDB.realm and OmniInventoryDB.realm[realmName]
    if not realm then return end

    local hasAnyCounts = false
    local headerAdded = false

    -- Iterate over all characters on this realm
    for charName, charData in pairs(realm) do
        local bagsCount, bankCount, keyringCount = GetCharacterItemCounts(charData, targetItemID)
        local total = bagsCount + bankCount + keyringCount

        if total > 0 then
            -- Add header line on the first match
            if not headerAdded then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cFF00FF00OmniInventory Counts:|r")
                headerAdded = true
            end

            -- Format details: e.g. "5 (Bags: 3, Bank: 2, Keyring: 1)"
            local details = {}
            if bagsCount > 0 then
                table.insert(details, "Bags: " .. bagsCount)
            end
            if bankCount > 0 then
                table.insert(details, "Bank: " .. bankCount)
            end
            if keyringCount > 0 then
                table.insert(details, "Keyring: " .. keyringCount)
            end

            local detailsStr = ""
            if #details > 0 then
                detailsStr = string.format(" (%s)", table.concat(details, ", "))
            end

            local colorCode = GetClassColorCode(charData.class)
            local nameText = colorCode .. charName .. "|r"
            local countText = string.format(GOLD, total) .. string.format(SILVER, detailsStr)

            tooltip:AddDoubleLine(nameText, countText)
            hasAnyCounts = true
        end
    end

    if hasAnyCounts then
        tooltip:Show()
    end
end

-- Hook tooltip scripts
local function HookTooltip(tooltip)
    if not tooltip then return end
    tooltip:HookScript("OnTooltipSetItem", function(self)
        local _, link = self:GetItem()
        if link then
            local success, err = pcall(AddOwnerCounts, self, link)
            if not success then
                -- Silently fail to not disrupt game tooltips
            end
        end
    end)
end

-- Register hooks
HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)

print("|cFF00FF00OmniInventory|r: Cross-character tooltips hook loaded")
