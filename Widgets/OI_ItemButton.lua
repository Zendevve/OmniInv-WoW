-- =============================================================================
-- OmniInventory Item Button Widget
-- =============================================================================
-- Reusable item slot with icon, count, quality border, tooltip, pooling.
-- =============================================================================

local addonName, OI = ...

OI.ItemButton = {}
local ItemButton = OI.ItemButton

local BUTTON_SIZE = 37

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
    [7] = { 0.00, 0.80, 1.00 },
}

local buttonCount = 0

function ItemButton:Create(parent)
    buttonCount = buttonCount + 1
    local name = "OIItemButton" .. buttonCount

    local button = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints()
    button.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.count:SetPoint("BOTTOMRIGHT", -2, 2)
    button.count:SetJustifyH("RIGHT")

    button.borderTop = button:CreateTexture(nil, "OVERLAY")
    button.borderTop:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderTop:SetHeight(1)
    button.borderTop:SetPoint("TOPLEFT", 0, 0)
    button.borderTop:SetPoint("TOPRIGHT", 0, 0)

    button.borderBottom = button:CreateTexture(nil, "OVERLAY")
    button.borderBottom:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderBottom:SetHeight(1)
    button.borderBottom:SetPoint("BOTTOMLEFT", 0, 0)
    button.borderBottom:SetPoint("BOTTOMRIGHT", 0, 0)

    button.borderLeft = button:CreateTexture(nil, "OVERLAY")
    button.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderLeft:SetWidth(1)
    button.borderLeft:SetPoint("TOPLEFT", 0, 0)
    button.borderLeft:SetPoint("BOTTOMLEFT", 0, 0)

    button.borderRight = button:CreateTexture(nil, "OVERLAY")
    button.borderRight:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.borderRight:SetWidth(1)
    button.borderRight:SetPoint("TOPRIGHT", 0, 0)
    button.borderRight:SetPoint("BOTTOMRIGHT", 0, 0)

    button.glow = button:CreateTexture(nil, "OVERLAY")
    button.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    button.glow:SetBlendMode("ADD")
    button.glow:SetPoint("CENTER")
    button.glow:SetSize(BUTTON_SIZE * 1.5, BUTTON_SIZE * 1.5)
    button.glow:SetVertexColor(0.0, 1.0, 0.5, 1)
    button.glow:Hide()

    local ag = button.glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetChange(0.5)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    button.glow.anim = ag

    if OI.MasqueGroup then OI.MasqueGroup:AddButton(button) end

    button.upgradeArrow = button:CreateTexture(nil, "OVERLAY")
    button.upgradeArrow:SetTexture("Interface\\AddOns\\Pawn\\Textures\\UpgradeArrow")
    button.upgradeArrow:SetSize(23, 23)
    button.upgradeArrow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.upgradeArrow:Hide()

    button.stockBadge = button:CreateTexture(nil, "OVERLAY")
    button.stockBadge:SetSize(14, 14)
    button.stockBadge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.stockBadge:Hide()

    button.stockText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.stockText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.stockText:SetTextColor(1, 1, 1, 1)
    button.stockText:SetFont(button.stockText:GetFont(), 8)
    button.stockText:Hide()

    button.dimOverlay = button:CreateTexture(nil, "OVERLAY", nil, 7)
    button.dimOverlay:SetAllPoints(button.icon)
    button.dimOverlay:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.dimOverlay:SetVertexColor(0, 0, 0, 0.7)
    button.dimOverlay:Hide()

    button.pinIcon = button:CreateTexture(nil, "OVERLAY")
    button.pinIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_1")
    button.pinIcon:SetSize(14, 14)
    button.pinIcon:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    button.pinIcon:Hide()

    button.ilvlText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    button.ilvlText:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    button.ilvlText:SetTextColor(1, 1, 1, 1)
    button.ilvlText:Hide()

    button.questText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.questText:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    button.questText:SetText("!")
    button.questText:SetTextColor(1.0, 0.82, 0.0)
    button.questText:Hide()

    button.itemInfo = nil

    button:SetScript("PostClick", function(self, mb) ItemButton:OnClick(self, mb) end)
    button:SetScript("OnEnter", function(self) ItemButton:OnEnter(self) end)
    button:SetScript("OnLeave", function(self) ItemButton:OnLeave(self) end)
    button:SetScript("OnDragStart", function(self) ItemButton:OnDragStart(self) end)
    button:SetScript("OnReceiveDrag", function(self) ItemButton:OnReceiveDrag(self) end)

    return button
end

-- =============================================================================
-- SetItem
-- =============================================================================

function ItemButton:SetItem(button, itemInfo)
    if not button then return end
    if itemInfo and itemInfo.link and not itemInfo.hyperlink then
        itemInfo.hyperlink = itemInfo.link
    end
    if itemInfo and itemInfo.texture and not itemInfo.iconFileID then
        itemInfo.iconFileID = itemInfo.texture
    end
    if itemInfo and itemInfo.count and not itemInfo.stackCount then
        itemInfo.stackCount = itemInfo.count
    end
    button.itemInfo = itemInfo

    if not itemInfo then
        button.icon:SetTexture(nil)
        button.count:SetText("")
        local grey = 0.3
        if button.borderTop then button.borderTop:SetVertexColor(grey, grey, grey, 1) end
        if button.borderBottom then button.borderBottom:SetVertexColor(grey, grey, grey, 1) end
        if button.borderLeft then button.borderLeft:SetVertexColor(grey, grey, grey, 1) end
        if button.borderRight then button.borderRight:SetVertexColor(grey, grey, grey, 1) end
        button.glow:Hide()
        button.dimOverlay:Hide()
        button:SetAttribute("type", nil)
        button:SetAttribute("item", nil)
        return
    end

    button.icon:SetTexture(itemInfo.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")

    local count = itemInfo.stackCount or 1
    button.count:SetText(count > 1 and count or "")

    local quality = itemInfo.quality or 1
    local color = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
    if button.borderTop then button.borderTop:SetVertexColor(color[1], color[2], color[3], 1) end
    if button.borderBottom then button.borderBottom:SetVertexColor(color[1], color[2], color[3], 1) end
    if button.borderLeft then button.borderLeft:SetVertexColor(color[1], color[2], color[3], 1) end
    if button.borderRight then button.borderRight:SetVertexColor(color[1], color[2], color[3], 1) end

    button.bagID = itemInfo.bagID
    button.slotID = itemInfo.slotID

    local isOffline = false
    if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then
        isOffline = true
    elseif itemInfo.bagID == -1 or (itemInfo.bagID >= 5 and itemInfo.bagID <= 11) then
        isOffline = not (OI.Frame and OI.Frame:IsBankOpen())
    end

    if isOffline then
        button:SetAttribute("type", nil)
        button:SetAttribute("item", nil)
    else
        button:SetAttribute("type", "item")
        button:SetAttribute("item", itemInfo.bagID .. " " .. itemInfo.slotID)
    end

    if itemInfo.isNew and not isOffline then
        button.glow:Show()
        if button.glow.anim then button.glow.anim:Play() end
    else
        if button.glow.anim then button.glow.anim:Stop() end
        button.glow:Hide()
    end

    button.upgradeArrow:Hide()
    if PawnIsContainerItemAnUpgrade and itemInfo.bagID and itemInfo.bagID >= 0 and not isOffline then
        local ok, isUpgrade = pcall(PawnIsContainerItemAnUpgrade, itemInfo.bagID, itemInfo.slotID)
        if ok and isUpgrade then button.upgradeArrow:Show() end
    end

    button.ilvlText:Hide()
    if itemInfo.hyperlink then
        local _, _, _, iLvl, _, itemType = GetItemInfo(itemInfo.hyperlink)
        if iLvl and iLvl > 0 and (itemType == "Weapon" or itemType == "Armor") then
            button.ilvlText:SetText(iLvl)
            button.ilvlText:Show()
        end
    end

    button.questText:Hide()
    if itemInfo.bagID and itemInfo.bagID >= 0 and itemInfo.slotID and itemInfo.slotID > 0 then
        if GetContainerItemQuestInfo then
            local isQuestItem = GetContainerItemQuestInfo(itemInfo.bagID, itemInfo.slotID)
            if isQuestItem then
                button.questText:Show()
                if not itemInfo.quality or itemInfo.quality <= 1 then
                    local gold = { r = 1.0, g = 0.82, b = 0.0 }
                    if button.borderTop then button.borderTop:SetVertexColor(gold.r, gold.g, gold.b, 1) end
                    if button.borderBottom then button.borderBottom:SetVertexColor(gold.r, gold.g, gold.b, 1) end
                    if button.borderLeft then button.borderLeft:SetVertexColor(gold.r, gold.g, gold.b, 1) end
                    if button.borderRight then button.borderRight:SetVertexColor(gold.r, gold.g, gold.b, 1) end
                end
            end
        end
    elseif itemInfo.category == "Quest Items" then
        button.questText:Show()
    end

    local isUnusable = false
    if itemInfo.hyperlink then
        if itemInfo.bagID and itemInfo.bagID >= 0 then
            isUnusable = OI.API:IsItemUnusable(itemInfo.bagID, itemInfo.slotID)
        else
            isUnusable = OI.API:IsItemUnusableLink(itemInfo.hyperlink)
        end
    end

    if itemInfo.isQuickFiltered then
        button.dimOverlay:Show()
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.4)
        button.icon:SetVertexColor(1, 1, 1)
    elseif isUnusable then
        button.dimOverlay:Hide()
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(1.0)
        button.icon:SetVertexColor(1.0, 0.3, 0.3)
    else
        button.dimOverlay:Hide()
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1.0)
        button.icon:SetVertexColor(1, 1, 1)
    end

    if itemInfo.itemID and OI.Data and OI.Data:IsPinned(itemInfo.itemID) then
        button.pinIcon:Show()
    else
        button.pinIcon:Hide()
    end

    button.stockBadge:Hide()
    button.stockText:Hide()
    if itemInfo.itemID and OI.Data and not isOffline then
        local stockChange = OI.Data:GetStockChange(itemInfo.itemID)
        if stockChange == "new" then
            button.stockBadge:SetTexture("Interface\\Minimap\\MinimapIcon\\Tracking")
            button.stockBadge:SetVertexColor(0.0, 1.0, 0.5, 1)
            button.stockBadge:Show()
        elseif stockChange == "up" then
            button.stockText:SetText("+")
            button.stockText:SetTextColor(0.0, 1.0, 0.5, 1)
            button.stockText:Show()
        elseif stockChange == "down" then
            button.stockText:SetText("-")
            button.stockText:SetTextColor(1.0, 0.3, 0.3, 1)
            button.stockText:Show()
        end
    end
end

-- =============================================================================
-- Search
-- =============================================================================

function ItemButton:SetSearchMatch(button, isMatch)
    if not button then return end
    if isMatch then
        button.dimOverlay:Hide()
        button.icon:SetDesaturated(false)
        button.icon:SetAlpha(1.0)
        button.icon:SetVertexColor(1, 1, 1)
    else
        button.dimOverlay:Show()
        button.icon:SetDesaturated(true)
        button.icon:SetAlpha(0.5)
        button.icon:SetVertexColor(1, 1, 1)
    end
end

function ItemButton:ClearSearch(button)
    if not button then return end
    button.dimOverlay:Hide()
    button.icon:SetDesaturated(false)
    button.icon:SetAlpha(1)
    button.icon:SetVertexColor(1, 1, 1)
end

-- =============================================================================
-- Events
-- =============================================================================

function ItemButton:OnClick(button, mouseButton)
    if not button or not button.itemInfo then return end

    if mouseButton == "LeftButton" and IsModifiedClick("CHATLINK") and button.itemInfo.hyperlink then
        ChatEdit_InsertLink(button.itemInfo.hyperlink)
        return
    end

    local isOffline = false
    if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then
        isOffline = true
    elseif button.bagID == -1 or (button.bagID >= 5 and button.bagID <= 11) then
        isOffline = not (OI.Frame and OI.Frame:IsBankOpen())
    end
    if isOffline then return end

    if button.itemInfo and button.itemInfo.isNew then
        button.itemInfo.isNew = false
        if button.glow.anim then button.glow.anim:Stop() end
        button.glow:Hide()
        if OI.Categorizer and button.itemInfo.itemID then
            OI.Categorizer:ClearNewItem(button.itemInfo.itemID)
        end
    end

    if mouseButton == "LeftButton" then
        if IsModifiedClick("DRESSUP") then
            DressUpItemLink(GetContainerItemLink(button.bagID, button.slotID))
        elseif IsModifiedClick("PICKUPACTION") then
            PickupContainerItem(button.bagID, button.slotID)
        elseif IsModifiedClick("SPLITSTACK") then
            local _, count = GetContainerItemInfo(button.bagID, button.slotID)
            if count and count > 1 then
                OpenStackSplitFrame(count, button, "BOTTOMRIGHT", "TOPRIGHT")
            end
        end
    elseif mouseButton == "RightButton" then
        if IsShiftKeyDown() and button.itemInfo.itemID then
            local isPinned = OI.Data:TogglePin(button.itemInfo.itemID)
            button.pinIcon:SetShown(isPinned)
            if OI.Frame then OI.Frame:UpdateLayout() end
        end
    end
end

function ItemButton:OnEnter(button)
    if not button or not button.itemInfo then return end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    if button.bagID and button.bagID >= 0 then
        GameTooltip:SetBagItem(button.bagID, button.slotID)
    elseif button.itemInfo.hyperlink then
        GameTooltip:SetHyperlink(button.itemInfo.hyperlink)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Bank Item (Offline)", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
end

function ItemButton:OnLeave(button)
    GameTooltip:Hide()
end

function ItemButton:OnDragStart(button)
    if not button then return end
    local isOffline = false
    if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then
        isOffline = true
    elseif button.bagID == -1 or (button.bagID >= 5 and button.bagID <= 11) then
        isOffline = not (OI.Frame and OI.Frame:IsBankOpen())
    end
    if isOffline then return end
    if button.bagID and button.slotID then PickupContainerItem(button.bagID, button.slotID) end
end

function ItemButton:OnReceiveDrag(button)
    if not button then return end
    local isOffline = false
    if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then
        isOffline = true
    elseif button.bagID == -1 or (button.bagID >= 5 and button.bagID <= 11) then
        isOffline = not (OI.Frame and OI.Frame:IsBankOpen())
    end
    if isOffline then return end
    if button.bagID and button.slotID then PickupContainerItem(button.bagID, button.slotID) end
end

-- =============================================================================
-- Reset (Pool Release)
-- =============================================================================

function ItemButton:Reset(button)
    if not button then return end
    button.itemInfo = nil
    button.bagID = nil
    button.slotID = nil
    button.icon:SetTexture(nil)
    button.count:SetText("")
    local grey = 0.3
    if button.borderTop then button.borderTop:SetVertexColor(grey, grey, grey, 1) end
    if button.borderBottom then button.borderBottom:SetVertexColor(grey, grey, grey, 1) end
    if button.borderLeft then button.borderLeft:SetVertexColor(grey, grey, grey, 1) end
    if button.borderRight then button.borderRight:SetVertexColor(grey, grey, grey, 1) end
    if button.glow.anim then button.glow.anim:Stop() end
    button.glow:Hide()
    button.dimOverlay:Hide()
    button.icon:SetDesaturated(false)
    button.icon:SetAlpha(1)
    button.ilvlText:Hide()
    button.questText:Hide()
    button.stockBadge:Hide()
    button.stockText:Hide()
    button:Hide()
end

print("|cFF00FF00OmniInventory|r: ItemButton loaded")
