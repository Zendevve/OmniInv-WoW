local addonName, NS = ...

NS.Config = {}

local defaults = {
    scale = 1.0,
    opacity = 1.0,
    sortOnUpdate = true,
    columnCount = 5,
    itemSize = 37,
    padding = 5,
    showTooltips = true,
    enableSearch = true,
}

function NS.Config:Init()
    ZenBagsDB = ZenBagsDB or {}
    
    -- Merge defaults
    for k, v in pairs(defaults) do
        if ZenBagsDB[k] == nil then
            ZenBagsDB[k] = v
        end
    end
end

function NS.Config:Get(key)
    return ZenBagsDB[key] or defaults[key]
end

function NS.Config:Set(key, value)
    ZenBagsDB[key] = value
end

function NS.Config:GetDefaults()
    return defaults
end
