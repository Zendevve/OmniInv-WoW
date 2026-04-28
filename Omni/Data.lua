-- =============================================================================
-- OmniInventory Data Persistence
-- =============================================================================
-- Manages SavedVariables and cross-character data
-- =============================================================================

local addonName, Omni = ...

Omni.Data = {}
local Data = Omni.Data

-- =============================================================================
-- Default Configuration
-- =============================================================================

local defaults = {
    global = {
        viewMode = "flow",      -- "grid", "flow", "list"
        sortMode = "category",  -- "category", "quality", "name", "ilvl", "usage"
        columns = 10,
        itemSize = 37,
        scale = 1.0,
        opacity = 0.95,
        enableVirtualStacks = true,
        enableEmptySlotCompression = true,
        attune = {
            enabled = true,
            showRedForNonAttunable = true,
            showBountyIcons = true,
            showAccountIcons = false,
            showResistIcons = true,
            showProgressText = true,
            showAccountAttuneText = false,
            faeMode = false,
            enableAnimations = true,
            animationSpeed = 0.15,
            enableTextAnimations = true,
            textAnimationSpeed = 0.2,
            forgeColors = {
                BASE = { r = 0.0, g = 1.0, b = 0.0, a = 1.0 },
                TITANFORGED = { r = 0.468, g = 0.532, b = 1.0, a = 1.0 },
                WARFORGED = { r = 0.872, g = 0.206, b = 0.145, a = 1.0 },
                LIGHTFORGED = { r = 0.527, g = 0.527, b = 0.266, a = 1.0 },
            },
            faeCompleteBarColor = { r = 0.95, g = 0.8, b = 0.2, a = 1.0 },
            nonAttunableBarColor = { r = 1.0, g = 0.0, b = 0.0, a = 1.0 },
            textColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        },
    },
    char = {
        position = nil,         -- { point, x, y }
        customRules = {},
        collapsedCategories = {},
        virtualStackOverrides = {},  -- { [itemID] = true }
    },
    realm = {},  -- Cross-character data stored here
}

local function CopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    local dst = {}
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = CopyTable(value)
        else
            dst[key] = value
        end
    end
    return dst
end

local function MergeDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = CopyTable(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Data:Init()
    OmniInventoryDB = OmniInventoryDB or {}

    -- Ensure all default keys exist
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.realm = OmniInventoryDB.realm or {}

    MergeDefaults(OmniInventoryDB.global, defaults.global)
    MergeDefaults(OmniInventoryDB.char, defaults.char)
    MergeDefaults(OmniInventoryDB.realm, defaults.realm)

    -- Store current character info
    local realmName = GetRealmName()
    local playerName = UnitName("player")
    local charKey = realmName .. "-" .. playerName

    OmniInventoryDB.realm[realmName] = OmniInventoryDB.realm[realmName] or {}
    OmniInventoryDB.realm[realmName][playerName] = OmniInventoryDB.realm[realmName][playerName] or {
        class = select(2, UnitClass("player")),
        lastSeen = time(),
        gold = 0,
        bags = {},
        bank = {},
    }

    self.charKey = charKey
    self.realmName = realmName
    self.playerName = playerName
end

-- =============================================================================
-- Accessors
-- =============================================================================

function Data:Get(key)
    return OmniInventoryDB.global[key]
end

function Data:Set(key, value)
    OmniInventoryDB.global[key] = value
end

function Data:GetChar(key)
    return OmniInventoryDB.char[key]
end

function Data:SetChar(key, value)
    OmniInventoryDB.char[key] = value
end

function Data:GetPlayerMoney()
    return GetMoney() or 0
end

-- =============================================================================
-- Cross-Character Data
-- =============================================================================

function Data:SaveCharacterInventory()
    local realm = OmniInventoryDB.realm[self.realmName]
    local char = realm and realm[self.playerName]
    if not char then return end

    char.gold = GetMoney()
    char.lastSeen = time()

    -- Save bag item strings (compact format)
    char.bags = {}
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local _, count = GetContainerItemInfo(bagID, slot)
                table.insert(char.bags, { link = link, count = count or 1 })
            end
        end
    end
end

function Data:SaveBankItems()
    local realm = OmniInventoryDB.realm[self.realmName]
    local char = realm and realm[self.playerName]
    if not char then return end

    -- Save bank item strings
    char.bank = {}

    -- Main bank (-1)
    local numSlots = GetContainerNumSlots(-1)
    for slot = 1, numSlots do
        local link = GetContainerItemLink(-1, slot)
        if link then
            local _, count = GetContainerItemInfo(-1, slot)
            table.insert(char.bank, { link = link, count = count or 1 })
        end
    end

    -- Bank bags (5-11)
    for bagID = 5, 11 do
        local numSlots = GetContainerNumSlots(bagID)
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local _, count = GetContainerItemInfo(bagID, slot)
                table.insert(char.bank, { link = link, count = count or 1 })
            end
        end
    end
end

function Data:GetAllCharacters()
    local chars = {}
    for realmName, realmData in pairs(OmniInventoryDB.realm or {}) do
        for playerName, charData in pairs(realmData) do
            table.insert(chars, {
                realm = realmName,
                name = playerName,
                class = charData.class,
                gold = charData.gold,
                lastSeen = charData.lastSeen,
            })
        end
    end
    return chars
end

-- =============================================================================
-- Favorites/Pin System
-- =============================================================================

function Data:PinItem(itemID)
    if not itemID then return end
    OmniInventoryDB.global.pinnedItems = OmniInventoryDB.global.pinnedItems or {}
    OmniInventoryDB.global.pinnedItems[itemID] = true
end

function Data:UnpinItem(itemID)
    if not itemID then return end
    if OmniInventoryDB.global.pinnedItems then
        OmniInventoryDB.global.pinnedItems[itemID] = nil
    end
end

function Data:IsPinned(itemID)
    if not itemID then return false end
    return OmniInventoryDB.global.pinnedItems and OmniInventoryDB.global.pinnedItems[itemID] == true
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
-- Item Usage Tracking
-- =============================================================================

function Data:TrackItemUsage(itemID)
    if not itemID then return end
    OmniInventoryDB.global.itemUsage = OmniInventoryDB.global.itemUsage or {}
    OmniInventoryDB.global.itemUsage[itemID] = (OmniInventoryDB.global.itemUsage[itemID] or 0) + 1
end

function Data:GetItemUsage(itemID)
    if not itemID then return 0 end
    return OmniInventoryDB.global.itemUsage and OmniInventoryDB.global.itemUsage[itemID] or 0
end

-- =============================================================================
-- Gear Sets
-- =============================================================================

function Data:GetGearSets()
    OmniInventoryDB.global.gearSets = OmniInventoryDB.global.gearSets or {}
    return OmniInventoryDB.global.gearSets
end

function Data:GetGearSet(name)
    local sets = self:GetGearSets()
    return sets[name] or {}
end

function Data:CreateGearSet(name)
    if not name or name == "" then return false end
    local sets = self:GetGearSets()
    if not sets[name] then
        sets[name] = {}
        return true
    end
    return false
end

function Data:DeleteGearSet(name)
    local sets = self:GetGearSets()
    if sets[name] then
        sets[name] = nil
        return true
    end
    return false
end

function Data:AddItemToGearSet(itemID, setName)
    if not itemID or not setName then return false end
    local sets = self:GetGearSets()
    if not sets[setName] then
        sets[setName] = {}
    end
    sets[setName][tostring(itemID)] = true
    return true
end

function Data:RemoveItemFromGearSet(itemID, setName)
    if not itemID or not setName then return false end
    local sets = self:GetGearSets()
    if sets[setName] then
        sets[setName][tostring(itemID)] = nil
    end
    return true
end

function Data:IsItemInGearSet(itemID, setName)
    if not itemID or not setName then return false end
    local sets = self:GetGearSets()
    return sets[setName] and sets[setName][tostring(itemID)] == true
end

function Data:GetItemGearSets(itemID)
    if not itemID then return {} end
    local sets = self:GetGearSets()
    local result = {}
    for setName, items in pairs(sets) do
        if items[tostring(itemID)] then
            table.insert(result, setName)
        end
    end
    return result
end

-- =============================================================================
-- Blizzard Gear Set Cache
-- =============================================================================

function Data:BuildBlizzardSetCache()
    local numSets = OmniC_Equipment and OmniC_Equipment.GetNumEquipmentSets()
        and OmniC_Equipment.GetNumEquipmentSets() or 0

    OmniInventoryDB.char.blizzardSetCache = {}
    self.blizzardItemToSets = {}

    for i = 1, numSets do
        local setName = OmniC_Equipment and OmniC_Equipment.GetEquipmentSetInfo(i)
        if setName then
            local itemIDs = OmniC_Equipment and OmniC_Equipment.GetEquipmentSetItemIDs(setName)
            if itemIDs then
                OmniInventoryDB.char.blizzardSetCache[setName] = {}
                for _, itemID in pairs(itemIDs) do
                    if itemID and itemID ~= 0 then
                        OmniInventoryDB.char.blizzardSetCache[setName][tostring(itemID)] = true
                        self.blizzardItemToSets[itemID] = self.blizzardItemToSets[itemID] or {}
                        if not self:_tableContains(self.blizzardItemToSets[itemID], setName) then
                            table.insert(self.blizzardItemToSets[itemID], setName)
                        end
                    end
                end
            end
        end
    end

    -- Sort set names for each item
    for itemID, sets in pairs(self.blizzardItemToSets) do
        table.sort(sets)
    end
end

function Data:_tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

Data._setMembershipCache = {}

function Data:ClearSetMembershipCache()
    self._setMembershipCache = {}
end

function Data:GetBlizzardSetsForItem(itemID)
    if not itemID then return {} end
    if not self.blizzardItemToSets then return {} end
    return self.blizzardItemToSets[itemID] or {}
end

function Data:GetAllSetMemberships(itemID)
    if not itemID then return {} end

    if self._setMembershipCache[itemID] then
        return self._setMembershipCache[itemID]
    end

    local allSets = {}
    local seen = {}

    -- Manual sets
    local manualSets = self:GetItemGearSets(itemID)
    for _, setName in ipairs(manualSets) do
        if not seen[setName] then
            seen[setName] = true
            table.insert(allSets, setName)
        end
    end

    -- Blizzard sets (only if cache is already built)
    if self.blizzardItemToSets then
        local blizzardSets = self:GetBlizzardSetsForItem(itemID)
        for _, setName in ipairs(blizzardSets) do
            if not seen[setName] then
                seen[setName] = true
                table.insert(allSets, setName)
            end
        end
    end

    table.sort(allSets)
    self._setMembershipCache[itemID] = allSets
    return allSets
end

function Data:IsItemInAnySet(itemID)
    if not itemID then return false end
    local allSets = self:GetAllSetMemberships(itemID)
    return #allSets > 0
end

function Data:GetPrimarySetName(itemID)
    local allSets = self:GetAllSetMemberships(itemID)
    if #allSets > 0 then
        return allSets[1]
    end
    return nil
end

function Data:GetAllGearSetNames()
    local names = {}
    local seen = {}

    -- Manual sets
    local manualSets = self:GetGearSets()
    for setName, _ in pairs(manualSets) do
        if not seen[setName] then
            seen[setName] = true
            table.insert(names, setName)
        end
    end

    -- Blizzard sets
    if OmniInventoryDB.char.blizzardSetCache then
        for setName, _ in pairs(OmniInventoryDB.char.blizzardSetCache) do
            if not seen[setName] then
                seen[setName] = true
                table.insert(names, setName)
            end
        end
    end

    table.sort(names)
    return names
end

-- =============================================================================
-- Category Collapse State
-- =============================================================================

function Data:IsCategoryCollapsed(category)
    if not category then return false end
    OmniInventoryDB.char.collapsedCategories = OmniInventoryDB.char.collapsedCategories or {}
    return OmniInventoryDB.char.collapsedCategories[category] == true
end

function Data:ToggleCategoryCollapsed(category)
    if not category then return false end
    OmniInventoryDB.char.collapsedCategories = OmniInventoryDB.char.collapsedCategories or {}
    local isCollapsed = OmniInventoryDB.char.collapsedCategories[category] == true
    OmniInventoryDB.char.collapsedCategories[category] = not isCollapsed
    return not isCollapsed
end

-- =============================================================================
-- Theme
-- =============================================================================

function Data:GetTheme()
    return OmniInventoryDB.global.theme or "dark"
end

function Data:SetTheme(theme)
    OmniInventoryDB.global.theme = theme
end

-- =============================================================================
-- Virtual Stack Overrides
-- =============================================================================

function Data:SetVirtualStackOverride(itemID, enabled)
    if not itemID then return end
    OmniInventoryDB.char.virtualStackOverrides = OmniInventoryDB.char.virtualStackOverrides or {}
    if enabled then
        OmniInventoryDB.char.virtualStackOverrides[itemID] = true
    else
        OmniInventoryDB.char.virtualStackOverrides[itemID] = nil
    end
end

function Data:GetVirtualStackOverride(itemID)
    if not itemID then return false end
    return OmniInventoryDB.char.virtualStackOverrides and OmniInventoryDB.char.virtualStackOverrides[itemID] == true
end

print("|cFF00FF00OmniInventory|r: Data module loaded")
