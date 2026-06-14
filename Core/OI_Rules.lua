-- =============================================================================
-- OmniInventory Custom Rule Engine
-- =============================================================================
-- Sandboxed Lua expressions for user-defined categorization.
-- =============================================================================

local addonName, OI = ...

OI.Rules = {}
local Rules = OI.Rules

local compiledRules = {}

-- =============================================================================
-- Operators
-- =============================================================================

local OPERATORS = {
    equals = function(a, b) return a == b end,
    not_equals = function(a, b) return a ~= b end,
    contains = function(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then return false end
        return string.find(string.lower(a), string.lower(b), 1, true) ~= nil
    end,
    starts_with = function(a, b)
        if type(a) ~= "string" or type(b) ~= "string" then return false end
        return string.sub(string.lower(a), 1, #b) == string.lower(b)
    end,
    greater_than = function(a, b) return (tonumber(a) or 0) > (tonumber(b) or 0) end,
    less_than = function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end,
    in_list = function(a, b)
        if type(b) ~= "table" then return false end
        for _, v in ipairs(b) do if a == v then return true end end
        return false
    end,
    not_in_list = function(a, b)
        if type(b) ~= "table" then return false end
        for _, v in ipairs(b) do if a == v then return false end end
        return true
    end,
}

-- =============================================================================
-- Built-in Expression Functions
-- =============================================================================

local BUILTIN_FUNCTIONS = {}

function BUILTIN_FUNCTIONS.Name(substring)
    local item = _G.__ruleItemContext
    if not item or not item.name or item.name == "" then return false end
    return string.find(string.lower(item.name), string.lower(tostring(substring)), 1, true) ~= nil
end

function BUILTIN_FUNCTIONS.Type(typeStr)
    local item = _G.__ruleItemContext
    if not item or not typeStr then return false end
    local t = string.lower(tostring(typeStr))
    if item.itemType and string.find(string.lower(item.itemType), t, 1, true) then return true end
    if item.itemSubType and string.find(string.lower(item.itemSubType), t, 1, true) then return true end
    return false
end

function BUILTIN_FUNCTIONS.Quality(level)
    local item = _G.__ruleItemContext
    if not item then return false end
    return item.quality == tonumber(level)
end

function BUILTIN_FUNCTIONS.Tooltip(text)
    local item = _G.__ruleItemContext
    if not item or not item.bagID or not item.slotID then return false end
    if not OI.API then return false end
    if item.bagID >= 0 then
        return OI.API:TooltipContains(item.bagID, item.slotID, tostring(text))
    else
        return OI.API:TooltipLinkContains(item.hyperlink, tostring(text))
    end
end

function BUILTIN_FUNCTIONS.BindsOnEquip()
    local item = _G.__ruleItemContext
    return item and item.bindType == "BoE"
end

function BUILTIN_FUNCTIONS.BindsOnPickup()
    local item = _G.__ruleItemContext
    return item and item.bindType == "BoP"
end

function BUILTIN_FUNCTIONS.ProfessionReagent()
    local item = _G.__ruleItemContext
    if not item then return false end
    if item.itemType == "Reagent" or item.itemType == "Trade Goods" then return true end
    local reagents = { Herb = true, Enchanting = true, Jewelcrafting = true, Metal = true, Stone = true, Leather = true, Cloth = true }
    return item.itemSubType and reagents[item.itemSubType] or false
end

function BUILTIN_FUNCTIONS.IsNew()
    local item = _G.__ruleItemContext
    if not item then return false end
    if item.isNew then return true end
    if item.itemID and OI.Categorizer then return OI.Categorizer:IsNewItem(item.itemID) end
    return false
end

-- =============================================================================
-- Sandbox
-- =============================================================================

local SAFE_ENV = {
    string = { find = string.find, match = string.match, lower = string.lower, upper = string.upper, sub = string.sub, len = string.len },
    math = { floor = math.floor, ceil = math.ceil, abs = math.abs, min = math.min, max = math.max },
    tonumber = tonumber, tostring = tostring, type = type, _G = _G,
}

local function AddBuiltinFunctions(env)
    for k, v in pairs(BUILTIN_FUNCTIONS) do env[k] = v end
end

local function CompileExpression(expression)
    if not expression or expression == "" then return nil, "Empty expression" end
    local code = "return function() return " .. expression .. " end"
    local chunk, err = loadstring(code)
    if not chunk then return nil, "Syntax error: " .. (err or "unknown") end
    local sandbox = {}
    for k, v in pairs(SAFE_ENV) do sandbox[k] = v end
    AddBuiltinFunctions(sandbox)
    setfenv(chunk, sandbox)
    local ok, result = pcall(chunk)
    if not ok then return nil, "Execution error: " .. (result or "unknown") end
    return result, nil
end

local function EvaluateExpression(itemInfo, expression)
    if not compiledRules[expression] then
        local func, err = CompileExpression(expression)
        if not func then return false end
        compiledRules[expression] = func
    end

    local context = {
        itemID = itemInfo.itemID, quality = itemInfo.quality,
        stackCount = itemInfo.stackCount, isBound = itemInfo.isBound,
        bagID = itemInfo.bagID, slotID = itemInfo.slotID,
    }
    if itemInfo.hyperlink then
        local name, _, _, iLvl, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
        context.name = name or ""
        context.iLvl = iLvl or 0
        context.itemType = itemType or ""
        context.itemSubType = itemSubType or ""
    end

    _G.__ruleItemContext = context
    local ok, result = pcall(compiledRules[expression])
    _G.__ruleItemContext = nil
    return ok and result == true
end

-- =============================================================================
-- Field Extractors
-- =============================================================================

local function GetFieldValue(itemInfo, field)
    if not itemInfo then return nil end
    if itemInfo[field] then return itemInfo[field] end
    if field == "name" and itemInfo.hyperlink then return GetItemInfo(itemInfo.hyperlink) end
    if (field == "itemType" or field == "itemSubType") and itemInfo.hyperlink then
        local _, _, _, _, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
        return field == "itemType" and itemType or itemSubType
    end
    if (field == "iLvl" or field == "itemLevel") and itemInfo.hyperlink then
        local _, _, _, iLvl = GetItemInfo(itemInfo.hyperlink)
        return iLvl
    end
    return nil
end

local function EvaluateCondition(itemInfo, condition)
    local fieldValue = GetFieldValue(itemInfo, condition.field)
    local op = OPERATORS[condition.operator]
    return op and op(fieldValue, condition.value) or false
end

local function EvaluateConditions(itemInfo, conditions, matchType)
    matchType = matchType or "all"
    if not conditions or #conditions == 0 then return false end
    for _, cond in ipairs(conditions) do
        local result = EvaluateCondition(itemInfo, cond)
        if matchType == "any" and result then return true end
        if matchType == "all" and not result then return false end
    end
    return matchType == "all"
end

-- =============================================================================
-- Rule API
-- =============================================================================

function Rules:MatchRule(itemInfo, rule)
    if not rule or not rule.enabled then return false end
    if rule.expression and rule.expression ~= "" then return EvaluateExpression(itemInfo, rule.expression) end
    if rule.conditions and #rule.conditions > 0 then return EvaluateConditions(itemInfo, rule.conditions, rule.matchType) end
    return false
end

function Rules:FindMatchingRule(itemInfo)
    local rules = self:GetAllRules()
    table.sort(rules, function(a, b) return (a.priority or 99) < (b.priority or 99) end)
    for _, rule in ipairs(rules) do
        if self:MatchRule(itemInfo, rule) then return rule end
    end
    return nil
end

function Rules:GetAllRules()
    OI.db.char.customRules = OI.db.char.customRules or {}
    return OI.db.char.customRules
end

function Rules:AddRule(rule)
    if not rule or not rule.name then return false end
    rule.id = rule.id or tostring(GetTime()) .. "_" .. math.random(1000, 9999)
    rule.enabled = rule.enabled ~= false
    rule.priority = rule.priority or 50
    table.insert(OI.db.char.customRules, rule)
    if rule.expression then compiledRules[rule.expression] = nil end
    return true
end

function Rules:RemoveRule(ruleId)
    local rules = self:GetAllRules()
    for i, rule in ipairs(rules) do
        if rule.id == ruleId then
            if rule.expression then compiledRules[rule.expression] = nil end
            table.remove(rules, i)
            return true
        end
    end
    return false
end

function Rules:UpdateRule(ruleId, updates)
    local rules = self:GetAllRules()
    for _, rule in ipairs(rules) do
        if rule.id == ruleId then
            for k, v in pairs(updates) do rule[k] = v end
            if updates.expression then compiledRules[updates.expression] = nil end
            return true
        end
    end
    return false
end

function Rules:ToggleRule(ruleId)
    local rules = self:GetAllRules()
    for _, rule in ipairs(rules) do
        if rule.id == ruleId then rule.enabled = not rule.enabled return true end
    end
    return false
end

function Rules:Init()
    OI.db.char.customRules = OI.db.char.customRules or {}
end

print("|cFF00FF00OmniInventory|r: Rules engine loaded")
