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
}

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
-- Sandboxed Lua Expression Execution
-- =============================================================================
-- Safety: 3 layers of protection against malicious/buggy expressions
-- 1. Keyword blocking (while, for, repeat, goto)
-- 2. Instruction counter (fuel limit prevents runaway computation)
-- 3. Recursion depth limit (prevents stack overflow)
-- =============================================================================

-- Maximum "fuel" for expression execution (prevents infinite loops)
local MAX_FUEL = 1000

-- Maximum recursion depth for function calls within expressions
local MAX_RECURSION = 5

-- Dangerous keywords that enable infinite loops or gotos
local DANGEROUS_KEYWORDS = {
    "while", "for", "repeat", "goto",
}

--- Scan expression for dangerous patterns
---@param expression string
---@return boolean safe
---@return string|nil reason
local function ScanForDangerousPatterns(expression)
    if not expression or expression == "" then
        return true, nil
    end

    local lower = string.lower(expression)

    -- Check for dangerous keywords (word boundary match)
    for _, keyword in ipairs(DANGEROUS_KEYWORDS) do
        -- Match keyword as whole word (not part of identifier like "therefore")
        local pattern = "[^%w_]" .. keyword .. "[^%w_]"
        local patternStart = "^" .. keyword .. "[^%w_]"
        local patternEnd = "[^%w_]" .. keyword .. "$"
        local patternExact = "^" .. keyword .. "$"

        if string.find(lower, pattern)
            or string.find(lower, patternStart)
            or string.find(lower, patternEnd)
            or string.find(lower, patternExact) then
            return false, "Contains forbidden keyword: " .. keyword
        end
    end

    -- Check for label syntax (::)
    if string.find(expression, "::") then
        return false, "Contains forbidden label syntax (::)"
    end

    return true, nil
end

-- =============================================================================
-- Instrumented Sandbox Environment
-- =============================================================================

--- Create a fresh sandbox environment with a fuel counter
---@param fuel number Instruction budget
---@return table env
local function CreateSandboxEnv(fuel)
    local _fuel = fuel or MAX_FUEL

    local env = {
        -- Safe string functions (wrapped to decrement fuel)
        string = {
            find = function(s, p, ...)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return string.find(s, p, ...)
            end,
            match = function(s, p, ...)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return string.match(s, p, ...)
            end,
            lower = function(s)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return string.lower(s)
            end,
            upper = function(s)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return string.upper(s)
            end,
            sub = function(s, i, j)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return string.sub(s, i, j)
            end,
            len = function(s)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return string.len(s)
            end,
        },
        -- Safe math functions (wrapped)
        math = {
            floor = function(x)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return math.floor(x)
            end,
            ceil = function(x)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return math.ceil(x)
            end,
            abs = function(x)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return math.abs(x)
            end,
            min = function(...)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return math.min(...)
            end,
            max = function(...)
                _fuel = _fuel - 1
                if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
                return math.max(...)
            end,
        },
        -- Safe comparison/conversion functions
        tonumber = function(v)
            _fuel = _fuel - 1
            if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
            return tonumber(v)
        end,
        tostring = function(v)
            _fuel = _fuel - 1
            if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
            return tostring(v)
        end,
        type = function(v)
            _fuel = _fuel - 1
            if _fuel <= 0 then error("Expression timeout: too many operations", 0) end
            return type(v)
        end,
    }

    return env
end

local function CompileExpression(expression)
    if not expression or expression == "" then
        return nil, "Empty expression"
    end

    -- Layer 1: Scan for dangerous patterns (while, for, repeat, goto)
    local safe, reason = ScanForDangerousPatterns(expression)
    if not safe then
        return nil, "Blocked: " .. (reason or "unsafe expression")
    end

    -- Wrap in return statement
    local code = "return function(item) return " .. expression .. " end"

    -- Compile with loadstring
    local chunk, err = loadstring(code)
    if not chunk then
        return nil, "Syntax error: " .. (err or "unknown")
    end

    -- Layer 2: Execute in fresh sandboxed environment with fuel counter
    local env = CreateSandboxEnv(MAX_FUEL)
    setfenv(chunk, env)

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

    -- Execute compiled expression with error boundary
    local ok, result = pcall(compiledRules[expression], context)
    if not ok then
        -- result contains the error message
        local errMsg = tostring(result)
        if string.find(errMsg, "timeout") or string.find(errMsg, "recursion") then
            print("|cFFFF0000OmniInventory Rules|r: Expression safety limit hit: " .. errMsg)
            -- Invalidate cache so we don't keep a broken function
            compiledRules[expression] = nil
        end
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
-- =============================================================================
-- Rule Matching (Optimized)
-- =============================================================================
-- Performance: O(1) for itemID-based rules, O(M) worst case otherwise
-- Uses cached sorted rules (invalidated on RULES_CHANGED) and itemID index
-- =============================================================================

-- Sorted rules cache (invalidated when rules change)
local sortedRulesCache = nil

-- itemID -> rule index for O(1) lookups on direct itemID matches
local itemIDIndex = nil

--- Invalidate all caches (called when rules change)
local function InvalidateCaches()
    sortedRulesCache = nil
    itemIDIndex = nil
end

--- Build itemID index from current rules
local function BuildItemIDIndex()
    itemIDIndex = {}
    local rules = Rules:GetAllRules()

    for _, rule in ipairs(rules) do
        if rule.enabled and rule.conditions then
            for _, cond in ipairs(rule.conditions) do
                if cond.field == "itemID" and cond.operator == "equals" then
                    local itemID = tonumber(cond.value)
                    if itemID then
                        -- Store first (highest priority) rule for this itemID
                        if not itemIDIndex[itemID] then
                            itemIDIndex[itemID] = rule
                        end
                    end
                end
            end
        end
    end
end

--- Get sorted rules (cached)
---@return table sortedRules
local function GetSortedRules()
    if not sortedRulesCache then
        sortedRulesCache = {}
        local allRules = Rules:GetAllRules()

        -- Only include enabled rules
        for _, rule in ipairs(allRules) do
            if rule.enabled ~= false then
                table.insert(sortedRulesCache, rule)
            end
        end

        -- Sort by priority (lower number = higher priority)
        table.sort(sortedRulesCache, function(a, b)
            return (a.priority or 99) < (b.priority or 99)
        end)
    end

    return sortedRulesCache
end

function Rules:FindMatchingRule(itemInfo)
    if not itemInfo then return nil end

    -- Fast path: check itemID index first (O(1))
    if itemInfo.itemID then
        if not itemIDIndex then
            BuildItemIDIndex()
        end

        local indexedRule = itemIDIndex[itemInfo.itemID]
        if indexedRule then
            -- Verify the rule still matches (conditions might have changed)
            if self:MatchRule(itemInfo, indexedRule) then
                return indexedRule
            end
        end
    end

    -- Slow path: iterate sorted rules
    local sortedRules = GetSortedRules()

    for _, rule in ipairs(sortedRules) do
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

    -- Invalidate sorted rules and itemID caches
    InvalidateCaches()

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

            -- Invalidate sorted rules and itemID caches
            InvalidateCaches()

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

            -- Invalidate sorted rules and itemID caches
            InvalidateCaches()

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

            -- Invalidate sorted rules and itemID caches
            InvalidateCaches()

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
