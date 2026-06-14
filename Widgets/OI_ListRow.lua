local addonName, OI = ...
OI.ListRow = {}
local ListRow = OI.ListRow

local ROW_HEIGHT = 18
local rowPool = {}
local activeRows = {}

function ListRow:Create(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(14, 14)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    row.itemType = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.itemType:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.itemType:SetWidth(100)
    row.itemType:SetJustifyH("LEFT")
    row.itemType:SetTextColor(0.7, 0.7, 0.7)

    row.quantity = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.quantity:SetPoint("RIGHT", -6, 0)
    row.quantity:SetJustifyH("RIGHT")

    row.iconBorder = row:CreateTexture(nil, "OVERLAY")
    row.iconBorder:SetAllPoints(row.icon)
    row.iconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.iconBorder:SetBlendMode("ADD")

    return row
end

function ListRow:SetItem(row, itemInfo, index)
    if not row or not itemInfo then return end

    if itemInfo.iconFileID then
        row.icon:SetTexture(itemInfo.iconFileID)
        row.icon:Show()
    else
        row.icon:Hide()
    end

    local name = itemInfo.name or "Unknown"
    if itemInfo.quality then
        local r, g, b = GetItemQualityColor(itemInfo.quality)
        row.name:SetTextColor(r, g, b)
    end
    row.name:SetText(name)

    if itemInfo.itemType then
        row.itemType:SetText(itemInfo.itemType .. (itemInfo.itemSubType and " - " .. itemInfo.itemSubType or ""))
    else
        row.itemType:SetText("")
    end

    local count = itemInfo.stackCount or 1
    row.quantity:SetText(count > 1 and count or "")

    local bgColor = (index % 2 == 0) and { 0.05, 0.05, 0.05, 0.4 } or { 0.08, 0.08, 0.08, 0.4 }
    row.bg:SetVertexColor(unpack(bgColor))

    row.bagID = itemInfo.bagID
    row.slotID = itemInfo.slotID
    row.itemInfo = itemInfo

    row:SetScript("OnEnter", function(self)
        if not self.bagID or not self.slotID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.bagID >= 0 then
            GameTooltip:SetBagItem(self.bagID, self.slotID)
        elseif self.itemInfo and self.itemInfo.hyperlink then
            GameTooltip:SetHyperlink(self.itemInfo.hyperlink)
        end
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row:Show()
end

function ListRow:Acquire(parent)
    local row
    if #rowPool > 0 then
        row = table.remove(rowPool)
        row:SetParent(parent)
    else
        row = self:Create(parent)
    end
    activeRows[row] = true
    return row
end

function ListRow:Release(row)
    if not row then return end
    activeRows[row] = nil
    row:Hide()
    row:ClearAllPoints()
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row.itemInfo = nil
    row.bagID = nil
    row.slotID = nil
    table.insert(rowPool, row)
end

function ListRow:ReleaseAll()
    for row in pairs(activeRows) do self:Release(row) end
end

print("|cFF00FF00OmniInventory|r: ListRow loaded")
