local addonName, OI = ...
OI.MinimapButton = {}
local MinimapButton = OI.MinimapButton

local minimapIcon = nil
local isDragging = false
local minimapRadius = 78

local function UpdateAngle(angle)
    if not minimapIcon then return end
    local radius = minimapRadius
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapIcon:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function GetAngle(x, y)
    local mx, my = Minimap:GetCenter()
    return math.atan2(y - my, x - mx)
end

local function OnDragStart(self)
    isDragging = true
    self:SetScript("OnUpdate", function(s, elapsed)
        local x, y = GetCursorPosition()
        local angle = GetAngle(x / UIParent:GetScale(), y / UIParent:GetScale())
        if self.dbKey then
            OI.db.global.minimapAngle = angle
        end
        UpdateAngle(angle)
    end)
end

local function OnDragStop(self)
    isDragging = false
    self:SetScript("OnUpdate", nil)
end

function MinimapButton:Show()
    if minimapIcon then minimapIcon:Show() end
end

function MinimapButton:Hide()
    if minimapIcon then minimapIcon:Hide() end
end

function MinimapButton:ResetPosition()
    if minimapIcon then
        minimapIcon:ClearAllPoints()
        minimapIcon:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -10, -10)
        OI.db.global.minimapAngle = nil
    end
end

function MinimapButton:Init()
    if minimapIcon then return end

    minimapIcon = CreateFrame("Button", "OIMinimapIcon", Minimap)
    minimapIcon:SetSize(32, 32)
    minimapIcon:SetFrameStrata("MEDIUM")
    minimapIcon:SetFrameLevel(8)
    minimapIcon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    minimapIcon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    minimapIcon:RegisterForDrag("LeftButton")
    minimapIcon.dbKey = true

    minimapIcon.icon = minimapIcon:CreateTexture(nil, "BACKGROUND")
    minimapIcon.icon:SetSize(20, 20)
    minimapIcon.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_07")
    minimapIcon.icon:SetPoint("CENTER")

    minimapIcon.border = minimapIcon:CreateTexture(nil, "OVERLAY")
    minimapIcon.border:SetSize(52, 52)
    minimapIcon.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    minimapIcon.border:SetPoint("TOPLEFT")

    minimapIcon:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            if OI.Frame then OI.Frame:Toggle() end
        elseif button == "RightButton" then
            if OI.Config then OI.Config:Open() end
        end
    end)

    minimapIcon:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFF00FF00Omni|rInventory " .. (OI.version or "2.0"))
        GameTooltip:AddLine("|cFFFFFFFFLeft-click|r Toggle bags")
        GameTooltip:AddLine("|cFFFFFFFFRight-click|r Settings")
        GameTooltip:AddLine("|cFFFFFFFFDrag|r Move icon")
        GameTooltip:Show()
    end)

    minimapIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)

    minimapIcon:SetScript("OnDragStart", OnDragStart)
    minimapIcon:SetScript("OnDragStop", OnDragStop)

    local savedAngle = OI.db.global.minimapAngle
    if savedAngle then
        UpdateAngle(savedAngle)
    else
        UpdateAngle(math.rad(225))
    end

    if not OI.db.global.showMinimap then
        minimapIcon:Hide()
    end
end

print("|cFF00FF00OmniInventory|r: MinimapButton loaded")
