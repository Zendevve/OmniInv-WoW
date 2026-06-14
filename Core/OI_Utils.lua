-- =============================================================================
-- OmniInventory Utilities
-- =============================================================================

local addonName, OI = ...

OI.Utils = {}
local Utils = OI.Utils

function Utils:ParseItemID(link)
    if not link then return nil end
    return tonumber(string.match(link, "item:(%d+)"))
end

function Utils:GetQualityColor(quality)
    if not quality or quality < 0 then return 0.62, 0.62, 0.62 end
    return GetItemQualityColor(quality)
end

function Utils:FormatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    if gold > 0 then return string.format("%dg %ds %dc", gold, silver, cop)
    elseif silver > 0 then return string.format("%ds %dc", silver, cop)
    else return string.format("%dc", cop) end
end

function Utils:CreateBackdrop(frame, r, g, b, a)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(r or 0.1, g or 0.1, b or 0.1, a or 0.95)
    frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

function Utils:DeepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in next, orig, nil do
        copy[self:DeepCopy(k)] = self:DeepCopy(v)
    end
    return setmetatable(copy, self:DeepCopy(getmetatable(orig)))
end

print("|cFF00FF00OmniInventory|r: Utils loaded")
