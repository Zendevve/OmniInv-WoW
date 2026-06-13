-- =============================================================================
-- OmniInventory Custom Rule Engine
-- =============================================================================
-- Purpose: Allow advanced users to define custom categorization rules
-- using a simple declarative format or sandboxed Lua expressions.
-- =============================================================================

local addonName, Omni = ...

Omni.Rules = {}
local Rules = Omni.Rules

-- =============================================================================
-- Rule Storage
-- =============================================================================

local compiledRules = {}  -- Cached compiled rule functions

-- =============================================================================
-- Rule Definition
-- =============================================================================

--[[
Rule format:
{
    name = "My Raid Consumables",
    enabled = true,
    priority = 5,
    category = "Raid Consumables",
    conditions = {
        { field = "itemType", operator = "equals", value = "Consumable" },
        { field = "name", operator = "contains", value = "Flask" },
    },
    -- OR simple Lua expression:
    expression = "itemType == 'Consumable' and name:match('Flask')",
}
]]

-- =============================================================================
-- Condition Operators
-- =============================================================================

local OPERATORS = {
    equals = function(a, b)
        return a == b
    end,

    not_equals = function(a, b)
        return a ~= b
    end,

    contains = function(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then
            return false
        end
        return string.find(string.lower(a), string.lower(b), 1, true) ~= nil
    end,

    starts_with = function(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then
            return false
        end
        return string.sub(string.lower(a), 1, #b) == string.lower(b)
    end,

    greater_than = function(a, b)
        return (tonumber(a) or 0) > (tonumber(b) or 0)
    end,

    less_than = function(a, b)
        return (tonumber(a) or 0) < (tonumber(b) or 0)
    end,

    in_list = function(a, b)
        if type(b) ~= "table" then return false end
        for _, v in ipairs(b) do
            if a == v then return true end
        end
        return false
    end,
    not_in_list = function(a, b)
        if type(b) ~= "table" then return false end
        for _, v in ipairs(b) do
            if a == v then return false end
        end
        return true
    end,
}

--- Get available rule operator types
function Rules:GetRuleTypes()
    -- Map operators to user-friendly names and input types
    return {
        { id = "equals", name = "Equals", type = "text" },
        { id = "not_equals", name = "Not Equals", type = "text" },
        { id = "contains", name = "Contains", type = "text" },
        { id = "starts_with", name = "Starts With", type = "text" },
        { id = "greater_than", name = "Greater Than", type = "number" },
        { id = "less_than", name = "Less Than", type = "number" },
        { id = "in_list", name = "In List (comma sep)", type = "text" },
        { id = "not_in_list", name = "Not In List", type = "text" },
    }
end

--- Get built-in expression functions available in the sandbox
function Rules:GetBuiltinFunctions()
    return {
        { name = "Name", desc = "Item name contains text", example = "Name(\"Flask\")" },
        { name = "Type", desc = "Item type/subtype matches", example = "Type(\"Armor\")" },
        { name = "Quality", desc = "Item quality equals level", example = "Quality(3)" },
        { name = "Tooltip", desc = "Tooltip contains text", example = "Tooltip(\"Use:\")" },
        { name = "BindsOnEquip", desc = "Item binds on equip (BoE)", example = "BindsOnEquip()" },
        { name = "BindsOnPickup", desc = "Item binds on pickup (BoP)", example = "BindsOnPickup()" },
        { name = "ProfessionReagent", desc = "Is a crafting reagent", example = "ProfessionReagent()" },
        { name = "IsNew", desc = "Acquired this session", example = "IsNew()" },
    }
end

--- Get pre-built rule templates for common categorization patterns
function Rules:GetRuleTemplates()
    return {
        {
            name = "Flasks & Potions",
            description = "Group consumable flasks and potions together",
            expression = "Name(\"Flask\") or Name(\"Potion\") or Name(\"Elixir\")",
            category = "Consumables",
        },
        {
            name = "Health/Mana Stones",
            description = "Health and mana stones for quick access",
            expression = "Name(\"Health Stone\") or Name(\"Mana Stone\") or Name(\"Soulstone\")",
            category = "Consumables",
        },
        {
            name = "Food & Drink",
            description = "Bread, water, and other food items",
            expression = "Type(\"Consumable\") and (Name(\"Bread\") or Name(\"Water\") or Name(\"Cheese\") or Name(\"Fish\") or Name(\"Meat\") or Name(\"Fruit\"))",
            category = "Consumables",
        },
        {
            name = "BoE Equipment (Sellable)",
            description = "Bind-on-equip items that can be sold on AH",
            expression = "BindsOnEquip() and Type(\"Weapon\") or Type(\"Armor\")",
            category = "Equipment",
        },
        {
            name = "BoP Equipment (Keep)",
            description = "Bind-on-pickup items to keep for personal use",
            expression = "BindsOnPickup() and (Type(\"Weapon\") or Type(\"Armor\"))",
            category = "Equipment",
        },
        {
            name = "Gems & Gems",
            description = "Precious gems for socketing",
            expression = "Type(\"Gem\")",
            category = "Gems",
        },
        {
            name = "Enchanting Materials",
            description = "Dust, shards, and essences for enchanting",
            expression = "Name(\"Dust\") or Name(\"Shard\") or Name(\"Essence\") or Name(\"Crystal\")",
            category = "Professions",
        },
        {
            name = "Herbs & Alchemy",
            description = "Herbs gathered for alchemy and inscription",
            expression = "ProfessionReagent() and (Name(\"Herb\") or Name(\"Leaf\") or Name(\"Bloom\") or Name(\"Thorn\") or Name(\"Root\"))",
            category = "Professions",
        },
        {
            name = "Quest Items",
            description = "Items needed for active quests",
            expression = "Tooltip(\"Quest\") or Tooltip(\"Quest Item\")",
            category = "Quest Items",
        },
        {
            name = "Keys & Passes",
            description = "Keys, lockboxes, and instance passes",
            expression = "Type(\"Key\") or Name(\"Key\") or Name(\"Pass\") or Name(\"Lock\")",
            category = "Miscellaneous",
        },
        {
            name = "Junk (Gray Items)",
            description = "Gray quality items safe to sell",
            expression = "Quality(0)",
            category = "Junk",
        },
        {
            name = "New Items (Session)",
            description = "Items acquired this session",
            expression = "IsNew()",
            category = "Special",
        },
    }
end

-- =============================================================================
-- Field Extractors
-- =============================================================================

local function GetFieldValue(itemInfo, field)
    if not itemInfo then return nil end

    -- Direct fields
    if itemInfo[field] then
        return itemInfo[field]
    end

    -- Computed fields
    if field == "name" then
        if itemInfo.hyperlink then
            local name = GetItemInfo(itemInfo.hyperlink)
            return name
        end
        return nil
    end

    if field == "itemType" or field == "itemSubType" then
        if itemInfo.hyperlink then
            local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
            return field == "itemType" and itemType or itemSubType
        end
        return nil
    end

    if field == "iLvl" or field == "itemLevel" then
        if itemInfo.hyperlink then
            local _, _, _, iLvl = GetItemInfo(itemInfo.hyperlink)
            return iLvl
        end
        return nil
    end

    return nil
end

-- =============================================================================
-- Rule Evaluation
-- =============================================================================

local function EvaluateCondition(itemInfo, condition)
    local fieldValue = GetFieldValue(itemInfo, condition.field)
    local operator = OPERATORS[condition.operator]

    if not operator then
        return false
    end

    return operator(fieldValue, condition.value)
end

local function EvaluateConditions(itemInfo, conditions, matchType)
    matchType = matchType or "all"  -- "all" (AND) or "any" (OR)

    if not conditions or #conditions == 0 then
        return false
    end

    for _, condition in ipairs(conditions) do
        local result = EvaluateCondition(itemInfo, condition)

        if matchType == "any" and result then
            return true
        elseif matchType == "all" and not result then
            return false
        end
    end

    return matchType == "all"
end

-- =============================================================================
-- Sandboxed Lua Expression Execution & Built-in Expression Functions
-- =============================================================================
-- Provides BagShui-equivalent functions available in expression sandbox.
-- Usage in expressions:
--   Name("suffix")    -- item name contains string
--   Type("Armor")     -- item type/subtype matches
--   Quality(3)        -- item quality equals or exceeds
--   Tooltip("text")   -- tooltip scan contains string
--   BindsOnEquip()    -- item binds when equipped
--   ProfessionReagent() -- item is a reagent (bagFamily check)
-- =============================================================================

local BUILTIN_FUNCTIONS = {}

--- Name(substring) - matches against item name (case-insensitive contains)
function BUILTIN_FUNCTIONS.Name(substring)
    local item = _G.__ruleItemContext
    if not item then return false end
    if not item.name or item.name == "" then return false end
    return string.find(string.lower(item.name), string.lower(tostring(substring)), 1, true) ~= nil
end

--- Type(typeStr) - matches itemType or itemSubType (partial match)
function BUILTIN_FUNCTIONS.Type(typeStr)
    local item = _G.__ruleItemContext
    if not item then return false end
    if not typeStr then return false end
    local t = string.lower(tostring(typeStr))
    if item.itemType and string.find(string.lower(item.itemType), t, 1, true) then return true end
    if item.itemSubType and string.find(string.lower(item.itemSubType), t, 1, true) then return true end
    return false
end

--- Quality(level) - matches item quality (numeric equality)
function BUILTIN_FUNCTIONS.Quality(level)
    local item = _G.__ruleItemContext
    if not item then return false end
    return item.quality == tonumber(level)
end

--- Tooltip(text) - scans tooltip for text match
function BUILTIN_FUNCTIONS.Tooltip(text)
    local item = _G.__ruleItemContext
    if not item or not item.bagID or not item.slotID then return false end
    if not Omni.API then return false end
    if item.bagID >= 0 then
        return Omni.API:TooltipContains(item.bagID, item.slotID, tostring(text))
    else
        return Omni.API:TooltipLinkContains(item.hyperlink, tostring(text))
    end
end

--- BindsOnEquip() - returns true for BoE items
function BUILTIN_FUNCTIONS.BindsOnEquip()
    local item = _G.__ruleItemContext
    if not item then return false end
    return item.bindType == "BoE"
end

--- BindsOnPickup() - returns true for BoP items
function BUILTIN_FUNCTIONS.BindsOnPickup()
    local item = _G.__ruleItemContext
    if not item then return false end
    return item.bindType == "BoP"
end

--- ProfessionReagent() - checks if item is a reagent via item type/subtype
function BUILTIN_FUNCTIONS.ProfessionReagent()
    local item = _G.__ruleItemContext
    if not item then return false end
    if item.itemType == "Reagent" then return true end
    if item.itemType == "Trade Goods" then return true end
    local reagents = { Herb = true, Enchanting = true, Jewelcrafting = true, Metal = true, Stone = true, Leather = true, Cloth = true }
    if item.itemSubType and reagents[item.itemSubType] then return true end
    return false
end

--- IsNew() - returns true if item was acquired this session
function BUILTIN_FUNCTIONS.IsNew()
    local item = _G.__ruleItemContext
    if not item then return false end
    if item.isNew then return true end
    if item.itemID and Omni.Categorizer then
        return Omni.Categorizer:IsNewItem(item.itemID)
    end
    return false
end

-- Copy built-in functions into sandbox
local function AddBuiltinFunctions(env)
    for k, v in pairs(BUILTIN_FUNCTIONS) do
        env[k] = v
    end
end

local SAFE_ENV = {
    -- Safe string functions
    string = {
        find = string.find,
        match = string.match,
        lower = string.lower,
        upper = string.upper,
        sub = string.sub,
        len = string.len,
    },
    -- Safe math functions
    math = {
        floor = math.floor,
        ceil = math.ceil,
        abs = math.abs,
        min = math.min,
        max = math.max,
    },
    -- Comparison
    tonumber = tonumber,
    tostring = tostring,
    type = type,
    -- Global table reference (needed for builtin context)
    _G = _G,
}

local function CompileExpression(expression)
    if not expression or expression == "" then
        return nil, "Empty expression"
    end

    -- Wrap in return statement
    local code = "return function() return " .. expression .. " end"

    -- Build full sandbox for compilation
    local compileSandbox = {}
    for k, v in pairs(SAFE_ENV) do
        compileSandbox[k] = v
    end
    AddBuiltinFunctions(compileSandbox)

    -- Compile with loadstring
    local chunk, err = loadstring(code)
    if not chunk then
        return nil, "Syntax error: " .. (err or "unknown")
    end

    -- Execute in full sandbox environment
    setfenv(chunk, compileSandbox)

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "Execution error: " .. (result or "unknown")
    end

    return result, nil
end

local function EvaluateExpression(itemInfo, expression)
    -- Check cache first
    if not compiledRules[expression] then
        local func, err = CompileExpression(expression)
        if not func then
            print("|cFFFF0000OmniInventory Rules|r: " .. err)
            return false
        end
        compiledRules[expression] = func
    end

    -- Build item context for expression
    local context = {
        itemID = itemInfo.itemID,
        quality = itemInfo.quality,
        stackCount = itemInfo.stackCount,
        isBound = itemInfo.isBound,
        bagID = itemInfo.bagID,
        slotID = itemInfo.slotID,
    }

    -- Add computed fields
    if itemInfo.hyperlink then
        local name, _, _, iLvl, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
        context.name = name or ""
        context.iLvl = iLvl or 0
        context.itemType = itemType or ""
        context.itemSubType = itemSubType or ""
    end

    -- Load built-in functions into sandbox environment
    local sandbox = {}
    for k, v in pairs(SAFE_ENV) do
        sandbox[k] = v
    end
    AddBuiltinFunctions(sandbox)

    -- Set global item context for builtin functions
    _G.__ruleItemContext = context

    -- Execute compiled expression
    local ok, result = pcall(compiledRules[expression])
    _G.__ruleItemContext = nil
    if not ok then
        return false
    end

    return result == true
end

-- =============================================================================
-- Rule Matching
-- =============================================================================

function Rules:MatchRule(itemInfo, rule)
    if not rule or not rule.enabled then
        return false
    end

    -- Check expression first (if defined)
    if rule.expression and rule.expression ~= "" then
        return EvaluateExpression(itemInfo, rule.expression)
    end

    -- Check conditions
    if rule.conditions and #rule.conditions > 0 then
        return EvaluateConditions(itemInfo, rule.conditions, rule.matchType)
    end

    return false
end

function Rules:FindMatchingRule(itemInfo)
    local rules = self:GetAllRules()

    -- Sort by priority
    table.sort(rules, function(a, b)
        return (a.priority or 99) < (b.priority or 99)
    end)

    for _, rule in ipairs(rules) do
        if self:MatchRule(itemInfo, rule) then
            return rule
        end
    end

    return nil
end

-- =============================================================================
-- Rule Management
-- =============================================================================

function Rules:GetAllRules()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.customRules = OmniInventoryDB.customRules or {}
    return OmniInventoryDB.customRules
end

function Rules:AddRule(rule)
    if not rule or not rule.name then return false end

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.customRules = OmniInventoryDB.customRules or {}

    -- Generate ID
    rule.id = rule.id or tostring(GetTime()) .. "_" .. math.random(1000, 9999)
    rule.enabled = rule.enabled ~= false
    rule.priority = rule.priority or 50

    table.insert(OmniInventoryDB.customRules, rule)

    -- Clear compiled cache for this expression
    if rule.expression then
        compiledRules[rule.expression] = nil
    end

    if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
    return true
end

function Rules:RemoveRule(ruleId)
    local rules = self:GetAllRules()

    for i, rule in ipairs(rules) do
        if rule.id == ruleId then
            -- Clear compiled cache
            if rule.expression then
                compiledRules[rule.expression] = nil
            end
            table.remove(rules, i)
            if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
            return true
        end
    end

    return false
end

function Rules:UpdateRule(ruleId, updates)
    local rules = self:GetAllRules()

    for _, rule in ipairs(rules) do
        if rule.id == ruleId then
            for k, v in pairs(updates) do
                rule[k] = v
            end
            -- Clear compiled cache if expression changed
            if updates.expression then
                compiledRules[rule.expression] = nil
            end
            if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
            return true
        end
    end

    return false
end

function Rules:ToggleRule(ruleId)
    local rules = self:GetAllRules()

    for _, rule in ipairs(rules) do
        if rule.id == ruleId then
            rule.enabled = not rule.enabled
            if Omni.Events then Omni.Events:FireEvent("RULES_CHANGED") end
            return true
        end
    end

    return false
end

-- =============================================================================
-- Preset Rules
-- =============================================================================

function Rules:LoadPresets()
    -- Only load if no rules exist
    if #self:GetAllRules() > 0 then
        return
    end

    -- Example preset rules
    local presets = {
        {
            name = "Hearthstone",
            priority = 1,
            category = "Hearthstone",
            conditions = {
                { field = "itemID", operator = "equals", value = 6948 },
            },
        },
        {
            name = "Food & Drink",
            priority = 20,
            category = "Consumables: Food",
            conditions = {
                { field = "itemSubType", operator = "in_list", value = { "Food & Drink", "Consumable" } },
            },
        },
    }

    for _, preset in ipairs(presets) do
        preset.isPreset = true
        self:AddRule(preset)
    end
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Rules:Init()
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.customRules = OmniInventoryDB.customRules or {}

    -- Optionally load presets
    -- self:LoadPresets()
end

print("|cFF00FF00OmniInventory|r: Rules engine loaded")
