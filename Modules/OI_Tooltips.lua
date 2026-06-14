local addonName, OI = ...

OI.Tooltips = {}
local Tooltips = OI.Tooltips

local currentPlayer = UnitName("player")
local TEAL = "|cff00ff9a%s|r"
local SILVER = "|cffc7c7cf%s|r"
local GOLD = "|cffffd700%s|r"

-- =============================================================================
-- Tooltip Cache Listener
-- =============================================================================

local function OnTooltipUpdated()
    if OI.Data then
        OI.Data:BuildTooltipCache()
    end
end

-- Register for cache updates after BAG_UPDATE debounce
function Tooltips:Init()
    if OI.Listen then
        OI:Listen(self, "TooltipUpdated", OnTooltipUpdated)
    end
end

function Tooltips:RefreshCache()
    OnTooltipUpdated()
end

-- =============================================================================
-- Tooltip Helpers
-- =============================================================================

local function GetClassColorCode(class)
    local color = class and RAID_CLASS_COLORS[class]
    if color then
        return string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255)
    end
    return TEAL
end

local function FormatCounts(bags, bank, equipped)
    local parts = {}
    if bags > 0 then table.insert(parts, (BAGNON_NUM_BAGS or "Bags: %d"):format(bags)) end
    if bank > 0 then table.insert(parts, (BAGNON_NUM_BANK or "Bank: %d"):format(bank)) end
    if equipped > 0 then table.insert(parts, BAGNON_EQUIPPED or "Equipped") end

    if #parts == 0 then return "" end

    local total = bags + bank + equipped
    if total == bags or total == bank or total == equipped then
        return format(TEAL, parts[1])
    end
    return format(TEAL, total) .. format(SILVER, format(" (%s)", strjoin(", ", unpack(parts))))
end

-- =============================================================================
-- Tooltip Hooks (Cached Ownership Display)
-- =============================================================================

local function AddOwners(frame, link)
    if not link then return end

    local cache = OI.Data and OI.Data:GetTooltipCache(link)
    if not cache then return end

    local hasAny = false

    for playerName, counts in pairs(cache) do
        if playerName ~= currentPlayer then
            local infoStr = FormatCounts(counts.bags or 0, counts.bank or 0, counts.equipped or 0)
            if infoStr ~= "" then
                local realm = OI.db and OI.db.realm and OI.db.realm[OI.realmName]
                local charData = realm and realm[playerName]
                local colorCode = charData and charData.class and GetClassColorCode(charData.class) or TEAL

                frame:AddDoubleLine(colorCode .. playerName .. "|r", infoStr)
                hasAny = true
            end
        end
    end

    if hasAny then
        frame:Show()
    end
end

local function HookTooltip(tooltip)
    if not tooltip then return end
    tooltip:HookScript("OnTooltipSetItem", function(self, ...)
        local itemLink = select(2, self:GetItem())
        if itemLink and GetItemInfo(itemLink) then
            AddOwners(self, itemLink)
        end
    end)
end

-- Hook both GameTooltip and ItemRefTooltip (parity with Bagnon)
HookTooltip(GameTooltip)
HookTooltip(ItemRefTooltip)

print("|cFF00FF00OmniInventory|r: Tooltips loaded")