local addonName, OI = ...
OI.Section = {}
local Section = OI.Section

local SECTION_HEADER_HEIGHT = 18

function Section:Create(parent, name, color, count)
    local header = CreateFrame("Frame", nil, parent)
    header:SetHeight(SECTION_HEADER_HEIGHT)

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.bg:SetVertexColor((color and color.r or 0.3) * 0.3, (color and color.g or 0.3) * 0.3, (color and color.b or 0.3) * 0.3, 0.6)

    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.text:SetPoint("LEFT", 4, 0)
    header.text:SetText(name or "Unknown")
    if color then header.text:SetTextColor(color.r, color.g, color.b) end

    header.count = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.count:SetPoint("RIGHT", -4, 0)
    header.count:SetTextColor(0.6, 0.6, 0.6)
    header.count:SetText(count and ("(" .. count .. ")") or "")

    header.collapseIcon = header:CreateTexture(nil, "OVERLAY")
    header.collapseIcon:SetSize(10, 10)
    header.collapseIcon:SetPoint("RIGHT", header.count, "LEFT", -2, 0)
    header.collapseIcon:SetTexture("Interface\\Buttons\\UI-ExpandButton-Up")
    header.collapseIcon:Hide()

    header.name = name
    header.collapsed = false

    return header
end

function Section:SetCollapsed(header, collapsed)
    if not header then return end
    header.collapsed = collapsed
    if collapsed then
        header.collapseIcon:SetTexture("Interface\\Buttons\\UI-ExpandButton-Up")
    else
        header.collapseIcon:SetTexture("Interface\\Buttons\\UI-CollapseButton-Up")
    end
end

function Section:SetCount(header, count)
    if not header then return end
    header.count:SetText(count and ("(" .. count .. ")") or "")
end

print("|cFF00FF00OmniInventory|r: Section loaded")
