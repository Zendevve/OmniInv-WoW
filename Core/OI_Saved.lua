-- =============================================================================
-- OmniInventory Data Persistence
-- =============================================================================
-- Cross-character data, stock tracking, profile import/export.
-- =============================================================================

local addonName, OI = ...

OI.Data = {}
local Data = OI.Data

Data.tooltipCache = {}
Data.stockChanges = {}

-- =============================================================================
-- Stock Snapshot
-- =============================================================================

local function BuildCurrentStockSnapshot()
    local snapshot = {}
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) or 0 do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                local _, count = GetContainerItemInfo(bagID, slot)
                if itemID then
                    snapshot[itemID] = (snapshot[itemID] or 0) + (count or 1)
                end
            end
        end
    end
    return snapshot
end

-- =============================================================================
-- Init
-- =============================================================================

function Data:Init()
    self:CompareStockSnapshots()
end

-- =============================================================================
-- Accessors
-- =============================================================================

function Data:Get(key) return OI.db.global[key] end
function Data:Set(key, value) OI.db.global[key] = value end
function Data:GetChar(key) return OI.db.char[key] end
function Data:SetChar(key, value) OI.db.char[key] = value end
function Data:GetPlayerMoney() return GetMoney() or 0 end

-- =============================================================================
-- Equipment Tracking
-- =============================================================================

function Data:SaveEquipment()
    local char = OI.db.realm[OI.realmName] and OI.db.realm[OI.realmName][OI.playerName]
    if not char then return end

    char.equipped = {}
    -- Slots 1-19 (invSlot 0 is head, 1 is neck, etc. - GetInventoryItemLink uses 1-19)
    for slot = 1, 19 do
        local link = GetInventoryItemLink("player", slot)
        if link then
            local count = GetInventoryItemCount("player", slot) or 1
            table.insert(char.equipped, { link = link, count = count })
        end
    end
end

-- =============================================================================
-- Cross-Character Inventory
-- =============================================================================

function Data:SaveCharacterInventory()
    local char = OI.db.realm[OI.realmName] and OI.db.realm[OI.realmName][OI.playerName]
    if not char then return end

    char.gold = GetMoney()
    char.lastSeen = time()

    char.bags = {}
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local _, count = GetContainerItemInfo(bagID, slot)
                table.insert(char.bags, { link = link, count = count or 1 })
            end
        end
    end

    self:SaveEquipment()
    char.stockSnapshot = BuildCurrentStockSnapshot()
    self:BuildTooltipCache()
end

function Data:SaveBankItems()
    local char = OI.db.realm[OI.realmName] and OI.db.realm[OI.realmName][OI.playerName]
    if not char then return end

    char.bank = {}
    for slot = 1, GetContainerNumSlots(-1) do
        local link = GetContainerItemLink(-1, slot)
        if link then
            local _, count = GetContainerItemInfo(-1, slot)
            table.insert(char.bank, { link = link, count = count or 1 })
        end
    end
    for bagID = 5, 11 do
        for slot = 1, GetContainerNumSlots(bagID) do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local _, count = GetContainerItemInfo(bagID, slot)
                table.insert(char.bank, { link = link, count = count or 1 })
            end
        end
    end
end

-- =============================================================================
-- Stock Change Tracking
-- =============================================================================

function Data:CompareStockSnapshots()
    local char = OI.db.realm[OI.realmName] and OI.db.realm[OI.realmName][OI.playerName]
    if not char then return end

    local prev = char.stockSnapshot or {}
    local cur = BuildCurrentStockSnapshot()
    local changes = {}

    for itemID, curCount in pairs(cur) do
        local prevCount = prev[itemID]
        if not prevCount then changes[itemID] = "new"
        elseif curCount > prevCount then changes[itemID] = "up" end
    end
    for itemID, prevCount in pairs(prev) do
        local curCount = cur[itemID]
        if not curCount then changes[itemID] = "down"
        elseif curCount < prevCount then changes[itemID] = "down" end
    end

    self.stockChanges = changes
end

function Data:GetStockChange(itemID)
    if not itemID or not self.stockChanges then return nil end
    return self.stockChanges[itemID]
end

function Data:ClearStockChanges() self.stockChanges = {} end

-- =============================================================================
-- Pin/Favorite System
-- =============================================================================

function Data:PinItem(itemID)
    if not itemID then return end
    OI.db.global.pinnedItems = OI.db.global.pinnedItems or {}
    OI.db.global.pinnedItems[itemID] = true
end

function Data:UnpinItem(itemID)
    if not itemID then return end
    if OI.db.global.pinnedItems then OI.db.global.pinnedItems[itemID] = nil end
end

function Data:IsPinned(itemID)
    if not itemID then return false end
    return OI.db.global.pinnedItems and OI.db.global.pinnedItems[itemID] == true
end

function Data:TogglePin(itemID)
    if self:IsPinned(itemID) then
        self:UnpinItem(itemID)
        return false
    else
        self:PinItem(itemID)
        return true
    end
end

-- =============================================================================
-- Character List
-- =============================================================================

function Data:GetAllCharacters()
    local chars = {}
    for realmName, realmData in pairs(OI.db.realm or {}) do
        for playerName, charData in pairs(realmData) do
            table.insert(chars, {
                realm = realmName, name = playerName,
                class = charData.class, gold = charData.gold,
                lastSeen = charData.lastSeen,
            })
        end
    end
    return chars
end

-- =============================================================================
-- Tooltip Cache (Cached Ownership Counts)
-- =============================================================================

--- Extract itemID from item link
---@param link string
---@return number|nil itemID
local function GetItemIDFromLink(link)
    if not link then return nil end
    return tonumber(string.match(link, "item:(%d+)"))
end

--- Build tooltip cache for all item links on the realm
--- Called after BAG_UPDATE events complete via message bus
function Data:BuildTooltipCache()
    wipe(self.tooltipCache)

    local realmName = OI.realmName
    local realm = OI.db and OI.db.realm and OI.db.realm[realmName]
    if not realm then return end

    for playerName, playerData in pairs(realm) do
        local playerCounts = {}

        -- Count bags
        if playerData.bags then
            for _, item in ipairs(playerData.bags) do
                local itemID = GetItemIDFromLink(item.link)
                if itemID then
                    if not playerCounts[itemID] then playerCounts[itemID] = { bags = 0, bank = 0, equipped = 0 } end
                    playerCounts[itemID].bags = playerCounts[itemID].bags + (item.count or 1)
                end
            end
        end

        -- Count bank
        if playerData.bank then
            for _, item in ipairs(playerData.bank) do
                local itemID = GetItemIDFromLink(item.link)
                if itemID then
                    if not playerCounts[itemID] then playerCounts[itemID] = { bags = 0, bank = 0, equipped = 0 } end
                    playerCounts[itemID].bank = playerCounts[itemID].bank + (item.count or 1)
                end
            end
        end

        -- Count equipped items
        if playerData.equipped then
            for _, item in ipairs(playerData.equipped) do
                local itemID = GetItemIDFromLink(item.link)
                if itemID then
                    if not playerCounts[itemID] then playerCounts[itemID] = { bags = 0, bank = 0, equipped = 0 } end
                    playerCounts[itemID].equipped = playerCounts[itemID].equipped + (item.count or 1)
                end
            end
        end

        -- Store in cache using short link key (item:ID) for fast lookup
        for itemID, counts in pairs(playerCounts) do
            local shortLink = "item:" .. itemID
            local cacheEntry = self.tooltipCache[shortLink]
            if not cacheEntry then
                cacheEntry = {}
                self.tooltipCache[shortLink] = cacheEntry
            end
            cacheEntry[playerName] = counts
        end
    end
end

--- Get ownership counts for an item link from cache
---@param link string
---@return table|nil counts { [player] = { bags = n, bank = n, equipped = n } }
function Data:GetTooltipCache(link)
    return self.tooltipCache[link]
end

--- Clear tooltip cache (called on bank/equipment changes)
function Data:WipeTooltipCache()
    wipe(self.tooltipCache)
end

print("|cFF00FF00OmniInventory|r: Data loaded")
