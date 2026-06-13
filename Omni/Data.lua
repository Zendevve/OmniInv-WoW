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
        showBagSlots = true,
    },
    char = {
        position = nil,         -- { point, x, y }
        customRules = {},
        collapsedCategories = {},
    },
    realm = {},  -- Cross-character data stored here
}

-- =============================================================================
-- Stock Change Tracking (Cross-Session)
-- =============================================================================
-- Compares current inventory against the previous session's snapshot
-- to detect items that were gained, lost, or had count changes.

--- Build a map of itemID -> count from current bags
---@return table snapshot { itemID = count }
local function BuildCurrentStockSnapshot()
    local snapshot = {}
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
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
-- Initialization
-- =============================================================================

function Data:Init()
    OmniInventoryDB = OmniInventoryDB or {}

    -- Ensure all default keys exist
    OmniInventoryDB.global = OmniInventoryDB.global or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.realm = OmniInventoryDB.realm or {}

    -- Merge defaults
    for k, v in pairs(defaults.global) do
        if OmniInventoryDB.global[k] == nil then
            OmniInventoryDB.global[k] = v
        end
    end

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
        keyring = {},
        stockSnapshot = {},  -- { itemID = count } from previous session
    }

    self.charKey = charKey
    self.realmName = realmName
    self.playerName = playerName

    -- Stock change tracking: compare current vs previous snapshot
    self:CompareStockSnapshots()
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

    -- Save keyring (compact format)
    char.keyring = {}
    local keyringSize = GetKeyRingSize and GetKeyRingSize() or 0
    if keyringSize > 0 then
        for slot = 1, keyringSize do
            local link = GetContainerItemLink(-2, slot)
            if link then
                local _, count = GetContainerItemInfo(-2, slot)
                table.insert(char.keyring, { link = link, count = count or 1 })
            end
        end
    end

    -- Save stock snapshot for next-session comparison
    char.stockSnapshot = BuildCurrentStockSnapshot()
end

-- =============================================================================
-- Stock Change Tracking (Cross-Session)
-- =============================================================================
-- Compares current inventory against the previous session's snapshot
-- to detect items that were gained, lost, or had count changes.

--- Compare current inventory against the previous session's snapshot
--- Populates self.stockChanges with detected changes.
function Data:CompareStockSnapshots()
    local realm = OmniInventoryDB.realm[self.realmName]
    local char = realm and realm[self.playerName]
    if not char then return end

    local previousSnapshot = char.stockSnapshot or {}
    local currentSnapshot = BuildCurrentStockSnapshot()
    local changes = {}

    -- Items gained or increased (current exists, previous didn't or lower)
    for itemID, curCount in pairs(currentSnapshot) do
        local prevCount = previousSnapshot[itemID]
        if not prevCount then
            changes[itemID] = "new"
        elseif curCount > prevCount then
            changes[itemID] = "up"
        end
    end

    -- Items lost or decreased (previous exists, current doesn't or lower)
    for itemID, prevCount in pairs(previousSnapshot) do
        local curCount = currentSnapshot[itemID]
        if not curCount then
            changes[itemID] = "down"
        elseif curCount < prevCount then
            changes[itemID] = "down"
        end
    end

    self.stockChanges = changes
    return changes
end

--- Save the current inventory as the new stock snapshot for next comparison
function Data:SaveStockSnapshot()
    local realm = OmniInventoryDB.realm[self.realmName]
    local char = realm and realm[self.playerName]
    if not char then return end

    char.stockSnapshot = BuildCurrentStockSnapshot()
end

--- Get the stock change type for an item
---@param itemID number
---@return string|nil changeType "new", "up", "down", or nil
function Data:GetStockChange(itemID)
    if not itemID or not self.stockChanges then return nil end
    return self.stockChanges[itemID]
end

--- Clear stock changes (call after first render)
function Data:ClearStockChanges()
    self.stockChanges = {}
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
-- Profile Import/Export
-- =============================================================================
-- Serialize and deserialize configuration for sharing between characters/players.

--- Escape a string for safe serialization
local function EscapeStr(s)
    if not s then return "" end
    return tostring(s):gsub("|", "||"):gsub("\n", "|n"):gsub("\r", "")
end

--- Unescape a serialized string
local function UnescapeStr(s)
    if not s then return "" end
    return tostring(s):gsub("|n", "\n"):gsub("||", "|")
end

--- Serialize a value to a string
local function SerializeValue(val)
    local t = type(val)
    if t == "nil" then
        return "nil"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return "\"" .. EscapeStr(val) .. "\""
    elseif t == "table" then
        local parts = {}
        -- Check if array-like
        local isArray = #val > 0
        if isArray then
            for _, v in ipairs(val) do
                table.insert(parts, SerializeValue(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        else
            for k, v in pairs(val) do
                if type(k) == "string" then
                    table.insert(parts, k .. "=" .. SerializeValue(v))
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return "\"\""
    end
end

--- Export the current profile as a shareable string
function Data:ExportProfile()
    local profile = {
        version = 1,
        global = {},
        char = {},
    }

    -- Copy global settings
    if OmniInventoryDB and OmniInventoryDB.global then
        for k, v in pairs(OmniInventoryDB.global) do
            if type(v) ~= "table" then
                profile.global[k] = v
            end
        end
        -- Pinned items
        if OmniInventoryDB.global.pinnedItems then
            profile.global.pinnedItems = {}
            for itemID in pairs(OmniInventoryDB.global.pinnedItems) do
                table.insert(profile.global.pinnedItems, itemID)
            end
        end
    end

    -- Copy char settings
    if OmniInventoryDB and OmniInventoryDB.char then
        if OmniInventoryDB.char.collapsedCategories then
            profile.char.collapsedCategories = {}
            for catName in pairs(OmniInventoryDB.char.collapsedCategories) do
                table.insert(profile.char.collapsedCategories, catName)
            end
        end
    end

    -- Copy rules
    if Omni.Rules then
        local rules = Omni.Rules:GetAllRules()
        profile.rules = {}
        for _, rule in ipairs(rules) do
            table.insert(profile.rules, {
                name = rule.name,
                expression = rule.expression,
                category = rule.category,
                enabled = rule.enabled,
                priority = rule.priority,
            })
        end
    end

    return "OmniInv:" .. SerializeValue(profile)
end

--- Deserialize a profile string
local function DeserializeProfile(str)
    if not str or str == "" then return nil, "Empty string" end

    -- Remove prefix
    str = str:gsub("^OmniInv:", "")
    if str == "" then return nil, "Invalid format" end

    -- Simple parser for our serialized format
    -- We'll use a safe approach: reconstruct the table manually
    local result = {}
    local pos = 1

    -- Skip leading brace
    str = str:match("^%s*{(.*)") or str
    str = str:match("(.*)}%s*$") or str

    -- Parse key=value pairs
    for key, val in str:gmatch("([%w_]+)%s*=%s*([^,{}]+)") do
        -- Parse value
        val = val:match("^%s*(.-)%s*$")
        if val == "true" then
            result[key] = true
        elseif val == "false" then
            result[key] = false
        elseif val == "nil" then
            result[key] = nil
        elseif val:match("^\"(.*)\"$") then
            result[key] = UnescapeStr(val:match("^\"(.*)\"$"))
        else
            local num = tonumber(val)
            if num then
                result[key] = num
            end
        end
    end

    return result
end

--- Import a profile from a string
function Data:ImportProfile(profileStr)
    if not profileStr or profileStr == "" then
        return false, "No profile data provided"
    end

    local profile, err = DeserializeProfile(profileStr)
    if not profile then
        return false, "Failed to parse profile: " .. (err or "unknown error")
    end

    -- Apply global settings
    if profile.global then
        for k, v in pairs(profile.global) do
            if k == "pinnedItems" and type(v) == "table" then
                OmniInventoryDB.global.pinnedItems = OmniInventoryDB.global.pinnedItems or {}
                for _, itemID in ipairs(v) do
                    OmniInventoryDB.global.pinnedItems[itemID] = true
                end
            else
                OmniInventoryDB.global[k] = v
            end
        end
    end

    -- Apply char settings
    if profile.char then
        if profile.char.collapsedCategories and type(profile.char.collapsedCategories) == "table" then
            OmniInventoryDB.char.collapsedCategories = OmniInventoryDB.char.collapsedCategories or {}
            for _, catName in ipairs(profile.char.collapsedCategories) do
                OmniInventoryDB.char.collapsedCategories[catName] = true
            end
        end
    end

    -- Apply rules
    if profile.rules and Omni.Rules then
        for _, rule in ipairs(profile.rules) do
            if rule.name and rule.expression then
                Omni.Rules:AddRule(rule.name, rule.expression, rule.category, rule.priority)
            end
        end
    end

    -- Refresh UI
    if Omni.Frame then
        Omni.Frame:ForceRender()
    end

    return true
end

--- Copy profile to chat for sharing
function Data:ShareProfile()
    local profileStr = self:ExportProfile()
    if profileStr then
        -- Print to chat for manual copy
        print("|cFF00FF00OmniInventory|r: Profile exported. Copy the line below:")
        print(profileStr)
        return profileStr
    end
    return nil
end

print("|cFF00FF00OmniInventory|r: Data module loaded")
