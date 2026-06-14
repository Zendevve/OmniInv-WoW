-- =============================================================================
-- OmniInventory Bag Slot Widget
-- =============================================================================
-- Bag slot buttons in header panel. Bag family coloring, drag/drop, purchase.
-- =============================================================================

local addonName, OI = ...

OI.BagSlot = {}
local BagSlot = OI.BagSlot

local SLOT_SIZE = 28
local SLOT_SPACING = 6

local BAG_FAMILY_COLORS = {
    [0x0001] = { 0.6, 0.4, 0.2 },  -- Ammo
    [0x0002] = { 0.4, 0.6, 0.4 },  -- Soul
    [0x0004] = { 0.4, 0.6, 0.4 },  -- Herb
    [0x0008] = { 0.4, 0.4, 0.6 },  -- Enchanting
    [0x0010] = { 0.6, 0.4, 0.4 },  -- Engineering
    [0x0020] = { 0.4, 0.4, 0.6 },  -- Gem
    [0x0040] = { 0.6, 0.6, 0.4 },  -- Mining
}

function BagSlot:GetBagFamilyColor(bagID)
    if bagID <= 0 then return nil end
    local _, bagFamily = GetContainerNumFreeSlots(bagID)
    if bagFamily and bagFamily > 0 then
        for family, color in pairs(BAG_FAMILY_COLORS) do
            if bit.band(bagFamily, family) ~= 0 then return color end
        end
    end
    return nil
end

function BagSlot:CreateButton(parent, index)
    local btn = CreateFrame("Button", "OIBagSlotBtn_" .. index, parent)
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)

    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    btn.icon = btn:CreateTexture(nil, "BORDER")
    btn.icon:SetAllPoints()
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    btn.Count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.Count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.Count:SetTextColor(1, 1, 1)

    btn:RegisterForClicks("anyUp")
    btn:RegisterForDrag("LeftButton")

    if OI.MasqueGroup then OI.MasqueGroup:AddButton(btn) end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.82, 0, 1)
        if OI.Frame then OI.Frame:SetBagHighlight(self.bagID) end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.bagID == 0 then
            GameTooltip:SetText(BACKPACK_TOOLTIP or "Backpack", 1, 1, 1)
        elseif self.bagID == -1 then
            GameTooltip:SetText(BANK or "Bank", 1, 1, 1)
        elseif self.isPurchasable then
            GameTooltip:SetText(BANK_BAG_PURCHASE or "Purchase Bank Bag Slot", 1, 1, 1)
            local cost = GetBankSlotCost(GetNumBankSlots())
            SetTooltipMoney(GameTooltip, cost)
        else
            if self.invSlot then
                local hasItem = GameTooltip:SetInventoryItem("player", self.invSlot)
                if not hasItem then
                    GameTooltip:SetText(EQUIP_CONTAINER or "Equip Container", 1, 1, 1)
                end
            end
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        if OI.Frame then OI.Frame:SetBagHighlight(nil) end
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self, button)
        if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then return end
        if self.isPurchasable then
            PlaySound("igMainMenuOption")
            StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
        elseif CursorHasItem() then
            if self.bagID == 0 then PutItemInBackpack()
            elseif self.invSlot then PutItemInBag(self.invSlot) end
        end
        if OI.Frame then OI.Frame:UpdateLayout() end
    end)

    btn:SetScript("OnDragStart", function(self)
        if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then return end
        if self.bagID ~= 0 and self.bagID ~= -1 and not self.isPurchasable and self.invSlot then
            PlaySound("BAGMENUBUTTONPRESS")
            PickupBagFromSlot(self.invSlot)
        end
    end)

    btn:SetScript("OnReceiveDrag", function(self)
        if OI.Frame and OI.Frame:GetViewedCharacter() ~= UnitName("player") then return end
        if not self.isPurchasable then
            if self.bagID == 0 then PutItemInBackpack()
            elseif self.invSlot then PutItemInBag(self.invSlot) end
        end
        if OI.Frame then OI.Frame:UpdateLayout() end
    end)

    return btn
end

function BagSlot:Create(parent, bagID)
    local btn = self:CreateButton(parent, bagID)
    self:UpdateButton(btn, bagID)
    btn:Show()
    return btn
end

function BagSlot:Release(btn)
    if not btn then return end
    btn:Hide()
    btn:ClearAllPoints()
    btn:SetScript("OnEnter", nil)
    btn:SetScript("OnLeave", nil)
    btn:SetScript("OnClick", nil)
    btn:SetScript("OnDragStart", nil)
    btn:SetScript("OnReceiveDrag", nil)
end

function BagSlot:UpdateButton(btn, bagID)
    btn.bagID = bagID
    btn.invSlot = bagID > 0 and ContainerIDToInventoryID(bagID) or nil
    btn.isPurchasable = false

    if bagID == 0 then
        btn.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
        btn.icon:SetVertexColor(1, 1, 1, 1)
    elseif bagID == -1 then
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
        btn.icon:SetVertexColor(1, 1, 1, 1)
    else
        if bagID >= 5 and bagID <= 11 then
            local numPurchased = GetNumBankSlots()
            if (bagID - 4) > numPurchased then btn.isPurchasable = true end
        end

        if btn.isPurchasable then
            btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
            btn.icon:SetVertexColor(1, 0.2, 0.2, 0.4)
        else
            local icon = btn.invSlot and GetInventoryItemTexture("player", btn.invSlot)
            if icon then
                btn.icon:SetTexture(icon)
                btn.icon:SetVertexColor(1, 1, 1, 1)
            else
                btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                btn.icon:SetVertexColor(1, 1, 1, 0.3)
            end
        end
    end

    if btn.invSlot and IsInventoryItemLocked(btn.invSlot) then
        btn.icon:SetDesaturated(true)
    else
        btn.icon:SetDesaturated(false)
    end

    if not btn.isPurchasable and bagID ~= -1 then
        local total = GetContainerNumSlots(bagID) or 0
        if total > 0 then
            local free = select(1, GetContainerNumFreeSlots(bagID)) or 0
            if free == 0 then
                btn.Count:SetText("0")
                btn.Count:SetTextColor(1, 0.2, 0.2)
                btn.Count:Show()
            elseif free < total then
                btn.Count:SetText(free)
                btn.Count:SetTextColor(0.8, 0.8, 0.8)
                btn.Count:Show()
            else
                btn.Count:Hide()
            end
        else
            btn.Count:Hide()
        end
    else
        btn.Count:Hide()
    end
end

print("|cFF00FF00OmniInventory|r: BagSlot loaded")
