-- =============================================================================
-- OmniInventory Categorizer
-- =============================================================================
-- Item categorization engine with priority pipeline and manual overrides.
-- =============================================================================

local addonName, OI = ...

OI.Categorizer = {}
local Categorizer = OI.Categorizer

-- =============================================================================
-- Category Colors
-- =============================================================================

local CATEGORY_COLORS = {
    ["Quest Items"]     = { r = 1.0, g = 0.82, b = 0.0 },
    ["Equipment"]       = { r = 0.0, g = 0.8, b = 0.0 },
    ["Equipment Sets"]  = { r = 0.4, g = 0.8, b = 1.0 },
    ["Consumables"]     = { r = 1.0, g = 0.5, b = 0.5 },
    ["Trade Goods"]     = { r = 0.8, g = 0.6, b = 0.4 },
    ["Reagents"]        = { r = 0.6, g = 0.4, b = 0.8 },
    ["Junk"]            = { r = 0.6, g = 0.6, b = 0.6 },
    ["New Items"]       = { r = 0.0, g = 1.0, b = 0.5 },
    ["Miscellaneous"]   = { r = 0.5, g = 0.5, b = 0.5 },
    ["Keys"]            = { r = 1.0, g = 0.9, b = 0.4 },
    ["Bags"]            = { r = 0.6, g = 0.4, b = 0.2 },
    ["Ammo"]            = { r = 0.8, g = 0.7, b = 0.5 },
    ["Glyphs"]          = { r = 0.5, g = 0.8, b = 1.0 },
}

-- =============================================================================
-- Category Registry
-- =============================================================================

local categories = {}
local categoryOrder = {}

function Categorizer:RegisterCategory(name, priority, icon, color, filterFunc)
    categories[name] = {
        name = name, priority = priority, icon = icon,
        color = color or CATEGORY_COLORS[name] or { r = 0.5, g = 0.5, b = 0.5 },
        filter = filterFunc,
    }
    categoryOrder = {}
    for _, catDef in pairs(categories) do
        table.insert(categoryOrder, catDef)
    end
    table.sort(categoryOrder, function(a, b) return a.priority < b.priority end)
end

function Categorizer:GetCategoryInfo(name)
    return categories[name] or {
        name = name, priority = 99,
        color = CATEGORY_COLORS[name] or { r = 0.5, g = 0.5, b = 0.5 },
    }
end

function Categorizer:GetCategoryColor(name)
    local info = self:GetCategoryInfo(name)
    return info.color.r, info.color.g, info.color.b
end

function Categorizer:GetAllCategories()
    return categoryOrder
end

-- =============================================================================
-- New Items Tracking
-- =============================================================================

local sessionItems = {}
local newItems = {}

function Categorizer:SnapshotInventory()
    sessionItems = {}
    for bagID = 0, 4 do
        for slot = 1, GetContainerNumSlots(bagID) or 0 do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID then sessionItems[itemID] = true end
            end
        end
    end
end

function Categorizer:IsNewItem(itemID)
    return itemID and newItems[itemID] == true
end

function Categorizer:MarkAsNew(itemID)
    if itemID and not sessionItems[itemID] then newItems[itemID] = true end
end

function Categorizer:ClearNewItem(itemID)
    if itemID then newItems[itemID] = nil end
end

-- =============================================================================
-- Classification
-- =============================================================================

local TYPE_TO_CATEGORY = {
    ["Armor"] = "Equipment", ["Weapon"] = "Equipment",
    ["Consumable"] = "Consumables", ["Trade Goods"] = "Trade Goods",
    ["Reagent"] = "Reagents", ["Recipe"] = "Trade Goods",
    ["Gem"] = "Trade Goods", ["Quest"] = "Quest Items",
    ["Key"] = "Keys", ["Miscellaneous"] = "Miscellaneous",
    ["Container"] = "Bags", ["Projectile"] = "Ammo",
    ["Quiver"] = "Bags", ["Glyph"] = "Glyphs",
    ["Potion"] = "Consumables", ["Elixir"] = "Consumables",
    ["Flask"] = "Consumables", ["Food & Drink"] = "Consumables",
    ["Bandage"] = "Consumables", ["Scroll"] = "Consumables",
    ["Leather"] = "Trade Goods", ["Metal & Stone"] = "Trade Goods",
    ["Cloth"] = "Trade Goods", ["Herb"] = "Trade Goods",
    ["Enchanting"] = "Trade Goods", ["Jewelcrafting"] = "Trade Goods",
    ["Parts"] = "Trade Goods", ["Devices"] = "Trade Goods",
    ["Explosives"] = "Trade Goods", ["Mount"] = "Miscellaneous",
    ["Companion Pets"] = "Miscellaneous", ["Holiday"] = "Miscellaneous",
}

local function ClassifyByItemType(itemInfo)
    if not itemInfo or not itemInfo.hyperlink then return "Miscellaneous" end
    local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
    if not itemType then return "Miscellaneous" end
    if itemSubType and TYPE_TO_CATEGORY[itemSubType] then return TYPE_TO_CATEGORY[itemSubType] end
    return TYPE_TO_CATEGORY[itemType] or "Miscellaneous"
end

local function IsQuestItem(itemInfo)
    if not itemInfo or not itemInfo.bagID or not itemInfo.slotID then return false end
    if GetContainerItemQuestInfo then
        local isQuestItem = GetContainerItemQuestInfo(itemInfo.bagID, itemInfo.slotID)
        return isQuestItem or false
    end
    return false
end

local function IsEquipmentSetItem(itemInfo)
    if not itemInfo or not itemInfo.hyperlink then return false end
    local numSets = GetNumEquipmentSets and GetNumEquipmentSets() or 0
    for i = 1, numSets do
        local name = GetEquipmentSetInfo(i)
        if name then
            local itemIDs = GetEquipmentSetItemIDs(name)
            if itemIDs then
                for _, itemID in pairs(itemIDs) do
                    if itemID == itemInfo.itemID then return true end
                end
            end
        end
    end
    return false
end

-- =============================================================================
-- Get Category (Pipeline)
-- =============================================================================

function Categorizer:GetCategory(itemInfo)
    if not itemInfo then return "Miscellaneous" end
    if itemInfo.bagID == -2 then return "Keys" end

    if itemInfo.itemID and OI.db and OI.db.global then
        local overrides = OI.db.char and OI.db.char.categoryOverrides
        if overrides and overrides[itemInfo.itemID] then
            return overrides[itemInfo.itemID]
        end
    end

    for _, catDef in ipairs(categoryOrder) do
        if catDef.filter then
            local result = catDef.filter(itemInfo)
            if type(result) == "string" then return result
            elseif result == true then return catDef.name end
        end
    end

    return ClassifyByItemType(itemInfo)
end

-- =============================================================================
-- Manual Overrides
-- =============================================================================

function Categorizer:SetManualOverride(itemID, categoryName)
    if not itemID or not categoryName then return end
    OI.db.char.categoryOverrides = OI.db.char.categoryOverrides or {}
    OI.db.char.categoryOverrides[itemID] = categoryName
end

function Categorizer:ClearManualOverride(itemID)
    if not itemID then return end
    if OI.db.char.categoryOverrides then
        OI.db.char.categoryOverrides[itemID] = nil
    end
end

-- =============================================================================
-- Init
-- =============================================================================

function Categorizer:Init()
    OI.db.char.categoryOverrides = OI.db.char.categoryOverrides or {}

    self:RegisterCategory("Custom Rules", 1.5, nil, nil, function(itemInfo)
        if OI.Rules then
            local matchedRule = OI.Rules:FindMatchingRule(itemInfo)
            if matchedRule and matchedRule.category then return matchedRule.category end
        end
    end)

    self:RegisterCategory("Quest Items", 2, nil, CATEGORY_COLORS["Quest Items"], function(itemInfo)
        return IsQuestItem(itemInfo)
    end)

    self:RegisterCategory("Equipment Sets", 3, nil, CATEGORY_COLORS["Equipment Sets"], function(itemInfo)
        return IsEquipmentSetItem(itemInfo)
    end)

    self:RegisterCategory("New Items", 4, nil, CATEGORY_COLORS["New Items"])

    self:RegisterCategory("Junk", 5, nil, CATEGORY_COLORS["Junk"], function(itemInfo)
        return itemInfo.quality == 0
    end)

    self:RegisterCategory("Equipment", 10, nil, CATEGORY_COLORS["Equipment"])
    self:RegisterCategory("Consumables", 11, nil, CATEGORY_COLORS["Consumables"])
    self:RegisterCategory("Trade Goods", 12, nil, CATEGORY_COLORS["Trade Goods"])
    self:RegisterCategory("Reagents", 13, nil, CATEGORY_COLORS["Reagents"])
    self:RegisterCategory("Keys", 15, nil, CATEGORY_COLORS["Keys"])
    self:RegisterCategory("Bags", 16, nil, CATEGORY_COLORS["Bags"])
    self:RegisterCategory("Ammo", 17, nil, CATEGORY_COLORS["Ammo"])
    self:RegisterCategory("Glyphs", 18, nil, CATEGORY_COLORS["Glyphs"])
    self:RegisterCategory("Miscellaneous", 98, nil, CATEGORY_COLORS["Miscellaneous"])

    self:RegisterCategory("Heuristics Fallback", 99, nil, nil, function(itemInfo)
        return ClassifyByItemType(itemInfo)
    end)

    self:SnapshotInventory()
end

print("|cFF00FF00OmniInventory|r: Categorizer loaded")
