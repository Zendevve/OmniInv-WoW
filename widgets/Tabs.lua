local addonName, NS = ...
local Frames = NS.Frames

-- =============================================================================
-- Tabs Logic
-- =============================================================================

function Frames:CreateTabs()
    self.mainFrame.numTabs = 2
    self.mainFrame.Tabs = {}

    -- Tab 1: Inventory (Custom Flat Style)
    self.inventoryTab = CreateFrame("Button", "ZenBagsInventoryTab", self.mainFrame)
    self.inventoryTab:SetSize(100, 25)
    self.inventoryTab:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 20, -25)

    -- Background
    self.inventoryTab.bg = self.inventoryTab:CreateTexture(nil, "BACKGROUND")
    self.inventoryTab.bg:SetAllPoints()
    self.inventoryTab.bg:SetTexture(0.12, 0.12, 0.12, 1)

    -- Text
    self.inventoryTab.text = self.inventoryTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.inventoryTab.text:SetPoint("CENTER")
    self.inventoryTab.text:SetText("Inventory")

    -- Active indicator (bottom border)
    self.inventoryTab.activeBorder = self.inventoryTab:CreateTexture(nil, "OVERLAY")
    self.inventoryTab.activeBorder:SetHeight(2)
    self.inventoryTab.activeBorder:SetPoint("BOTTOMLEFT")
    self.inventoryTab.activeBorder:SetPoint("BOTTOMRIGHT")
    self.inventoryTab.activeBorder:SetTexture(0.4, 0.6, 1.0, 1)

    self.inventoryTab:SetScript("OnClick", function() self:SwitchView("bags") end)
    table.insert(self.mainFrame.Tabs, self.inventoryTab)

    -- Tab 2: Bank (Custom Flat Style)
    self.bankTab = CreateFrame("Button", "ZenBagsBankTab", self.mainFrame)
    self.bankTab:SetSize(100, 25)
    self.bankTab:SetPoint("LEFT", self.inventoryTab, "RIGHT", 2, 0)

    -- Background
    self.bankTab.bg = self.bankTab:CreateTexture(nil, "BACKGROUND")
    self.bankTab.bg:SetAllPoints()
    self.bankTab.bg:SetTexture(0.12, 0.12, 0.12, 1)

    -- Text
    self.bankTab.text = self.bankTab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.bankTab.text:SetPoint("CENTER")
    self.bankTab.text:SetText("Bank")

    -- Active indicator (bottom border)
    self.bankTab.activeBorder = self.bankTab:CreateTexture(nil, "OVERLAY")
    self.bankTab.activeBorder:SetHeight(2)
    self.bankTab.activeBorder:SetPoint("BOTTOMLEFT")
    self.bankTab.activeBorder:SetPoint("BOTTOMRIGHT")
    self.bankTab.activeBorder:SetTexture(0.4, 0.6, 1.0, 1)

    self.bankTab:SetScript("OnClick", function() self:SwitchView("bank") end)
    table.insert(self.mainFrame.Tabs, self.bankTab)

    -- Set inventory as active by default
    self:SetActiveTab(1)

    -- Show bank tab if we have cached data
    if NS.Data:HasCachedBankItems() then
        self.bankTab:Show()
    else
        self.bankTab:Hide()
    end
end

function Frames:SetActiveTab(tabIndex)
    for i, tab in ipairs(self.mainFrame.Tabs) do
        if i == tabIndex then
            -- Active state: lighter background + blue border
            tab.bg:SetTexture(0.18, 0.18, 0.18, 1)
            tab.activeBorder:Show()
        else
            -- Inactive state: darker background, no border
            tab.bg:SetTexture(0.12, 0.12, 0.12, 1)
            tab.activeBorder:Hide()
        end
    end
end

function Frames:ShowBankTab()
    self.bankTab:Show()
end

function Frames:HideBankTab()
    self.bankTab:Hide()
end

function Frames:SwitchView(view)
    self.currentView = view

    if view == "bags" then
        self:SetActiveTab(1)
    else
        self:SetActiveTab(2)
    end

    NS.Inventory:SetFullUpdate(true)
    self:Update(true)
end
