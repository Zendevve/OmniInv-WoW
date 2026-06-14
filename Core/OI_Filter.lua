-- =============================================================================
-- OmniInventory Filter Registry
-- =============================================================================
-- Priority-based filter pipeline. Filters return section name or boolean.
-- =============================================================================

local addonName, OI = ...

OI.Filter = {}
local Filter = OI.Filter

local filters = {}
local filterOrder = {}

-- =============================================================================
-- Registration
-- =============================================================================

function Filter:Register(name, priority, filterFunc)
    filters[name] = {
        name = name,
        priority = priority,
        filter = filterFunc,
    }
    self:RebuildOrder()
end

function Filter:Unregister(name)
    filters[name] = nil
    self:RebuildOrder()
end

function Filter:RebuildOrder()
    filterOrder = {}
    for _, f in pairs(filters) do
        table.insert(filterOrder, f)
    end
    table.sort(filterOrder, function(a, b) return a.priority < b.priority end)
end

-- =============================================================================
-- Evaluation
-- =============================================================================

function Filter:Run(itemInfo)
    for _, f in ipairs(filterOrder) do
        if f.filter then
            local result = f.filter(itemInfo)
            if type(result) == "string" then return result
            elseif result == true then return f.name end
        end
    end
    return "Miscellaneous"
end

function Filter:GetAll()
    return filterOrder
end

function Filter:GetInfo(name)
    return filters[name]
end

function Filter:Init() end

print("|cFF00FF00OmniInventory|r: Filter registry loaded")
