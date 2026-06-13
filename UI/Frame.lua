-- =============================================================================
-- OmniInventory Main Frame
-- =============================================================================
-- Purpose: Primary window container with header, search, content area,
-- footer, and window management (move, resize, position persistence).
-- =============================================================================

local addonName, Omni = ...

Omni.Frame = {}
local Frame = Omni.Frame

-- =============================================================================
-- Constants
-- =============================================================================

local FRAME_MIN_WIDTH = 350
local FRAME_MIN_HEIGHT = 300
local FRAME_DEFAULT_WIDTH = 450
local FRAME_DEFAULT_HEIGHT = 400
local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 24
local SEARCH_HEIGHT = 24
local PADDING = 8
local ITEM_SIZE = 37
local ITEM_SPACING = 4

-- =============================================================================
-- Frame State
-- =============================================================================

local mainFrame = nil
local itemButtons = {}  -- Active item buttons
local categoryHeaders = {}  -- Active category header FontStrings
local listRows = {}  -- Track list row frames
local currentView = "grid"
local currentMode = "bags"
local isBankOpen = false
local isMerchantOpen = false
local isSearchActive = false
local searchText = ""

-- Dry-run / state diff optimization (from BagShui)
local lastLayoutState = nil  -- Cached layout fingerprint
local DRYRUN_ENABLED = true

-- Edit Mode
local editMode = false  -- Whether edit mode is active
local collapsedCategories = {}  -- { categoryName = true } -- categories collapsed in Flow view

-- =============================================================================
-- Frame Creation
-- =============================================================================

function Frame:CreateMainFrame()
    if mainFrame then return mainFrame end

    -- Main window
    mainFrame = CreateFrame("Frame", "OmniInventoryFrame", UIParent)
    mainFrame:SetSize(FRAME_DEFAULT_WIDTH, FRAME_DEFAULT_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetFrameLevel(100)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetMinResize(FRAME_MIN_WIDTH, FRAME_MIN_HEIGHT)

    -- Backdrop
    mainFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    mainFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    mainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    -- Apply saved scale
    local scale = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings and OmniInventoryDB.char.settings.scale
    mainFrame:SetScale(scale or 1)

    -- Make closable with ESC
    tinsert(UISpecialFrames, "OmniInventoryFrame")

    -- Create components
    self:CreateHeader()
    self:CreateSearchBar()
    self:CreateFilterBar()
    self:CreateBagPanel()
    self:CreateContentArea()
    self:CreateFooter()
    self:CreateResizeHandle()

    -- Register for updates
    self:RegisterEvents()

    -- Start hidden
    mainFrame:Hide()

    -- Simple fade-in animation (WoTLK 3.3.5a compatible - no AnimationGroups)
    local FADE_DURATION = 0.15  -- 150ms fade
    local fadeStartTime = nil

    local function FadeIn()
        fadeStartTime = GetTime()
        mainFrame:SetAlpha(0)
        mainFrame:SetScript("OnUpdate", function(self, elapsed)
            if not fadeStartTime then return end
            local progress = (GetTime() - fadeStartTime) / FADE_DURATION
            if progress >= 1 then
                self:SetAlpha(1)
                self:SetScript("OnUpdate", nil)
                fadeStartTime = nil
            else
                self:SetAlpha(progress)
            end
        end)
    end

    -- OnShow handler - trigger fade
    mainFrame:SetScript("OnShow", function(self)
        FadeIn()
        if Frame.UpdateFooterButton then Frame:UpdateFooterButton() end
    end)

    -- OnHide handler - auto-sort bags (physical)
    mainFrame:SetScript("OnHide", function(self)
        -- Only auto-sort if enabled (default: off)
        if OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.autoSortOnClose then
            Frame:PhysicalSortBags()
        end
    end)

    return mainFrame
end

-- =============================================================================
-- Header
-- =============================================================================

function Frame:CreateHeader()
    local header = CreateFrame("Frame", nil, mainFrame)
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", PADDING, -PADDING)
    header:SetPoint("TOPRIGHT", -PADDING, -PADDING)

    -- Background
    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()
    header.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    header.bg:SetVertexColor(0.15, 0.15, 0.15, 1)

    -- Title
    header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.title:SetPoint("LEFT", 6, 0)
    header.title:SetText("|cFF00FF00Omni|r Inventory")

    -- Close button
    header.closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    header.closeBtn:SetSize(20, 20)
    header.closeBtn:SetPoint("RIGHT", -2, 0)
    header.closeBtn:SetScript("OnClick", function()
        Frame:Hide()
    end)

    -- View toggle button
    header.viewBtn = CreateFrame("Button", nil, header)
    header.viewBtn:SetSize(50, 18)
    header.viewBtn:SetPoint("RIGHT", header.closeBtn, "LEFT", -4, 0)
    header.viewBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.viewBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.viewBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    header.viewBtn.text = header.viewBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.viewBtn.text:SetPoint("CENTER")
    header.viewBtn.text:SetText("Grid")

    header.viewBtn:SetScript("OnClick", function()
        Frame:CycleView()
    end)

    header.viewBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
    end)
    header.viewBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)

    -- Sort mode button
    header.sortBtn = CreateFrame("Button", nil, header)
    header.sortBtn:SetSize(50, 18)
    header.sortBtn:SetPoint("RIGHT", header.viewBtn, "LEFT", -4, 0)
    header.sortBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.sortBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.sortBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    header.sortBtn.text = header.sortBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.sortBtn.text:SetPoint("CENTER")
    header.sortBtn.text:SetText("Sort")

    header.sortBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header.sortBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            Frame:CycleSort()
        else
            Frame:PhysicalSortBags()
        end
    end)

    header.sortBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local mode = Omni.Sorter and Omni.Sorter:GetDefaultMode() or "category"
        GameTooltip:AddLine("Sort Bags", 1, 1, 1)
        GameTooltip:AddLine("Left-Click: Trigger physical tidy/sort", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-Click: Cycle mode (Current: " .. mode .. ")", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    header.sortBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)

    -- Edit Mode Toggle Button
    header.editBtn = CreateFrame("Button", nil, header)
    header.editBtn:SetSize(40, 18)
    header.editBtn:SetPoint("RIGHT", header.sortBtn, "LEFT", -4, 0)
    header.editBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.editBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.editBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    header.editBtn.text = header.editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.editBtn.text:SetPoint("CENTER")
    header.editBtn.text:SetText("Edit")
    header.editBtn:SetScript("OnClick", function()
        Frame:ToggleEditMode()
    end)
    header.editBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if editMode then
            GameTooltip:AddLine("Exit Edit Mode", 1, 1, 1)
            GameTooltip:AddLine("Category headers are clickable in Flow view", 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Enter Edit Mode", 1, 1, 1)
            GameTooltip:AddLine("Click category headers to collapse/expand", 0.8, 0.8, 0.8)
        end
        GameTooltip:Show()
    end)
    header.editBtn:SetScript("OnLeave", function(self)
        if editMode then
            self:SetBackdropColor(0.4, 0.3, 0.1, 1)
        else
            self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        end
        GameTooltip:Hide()
    end)

    -- Hearthstone Button (SecureActionButtonTemplate for combat safety)
    header.hearthBtn = CreateFrame("Button", nil, header, "SecureActionButtonTemplate")
    header.hearthBtn:SetSize(20, 20)
    header.hearthBtn:SetPoint("RIGHT", header.editBtn, "LEFT", -4, 0)
    header.hearthBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.hearthBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.hearthBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    header.hearthBtn.icon = header.hearthBtn:CreateTexture(nil, "ARTWORK")
    header.hearthBtn.icon:SetAllPoints()
    header.hearthBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Rune_01")
    header.hearthBtn:SetAttribute("type", "item")
    header.hearthBtn:Hide()

    -- Cooldown overlay for hearthstone
    header.hearthBtn.cooldown = CreateFrame("Cooldown", nil, header.hearthBtn, "CooldownFrameTemplate")
    header.hearthBtn.cooldown:SetAllPoints()
    header.hearthBtn.cooldown:Hide()

    header.hearthBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.itemName then
            GameTooltip:AddLine("Use Hearthstone", 1, 1, 1)
            GameTooltip:AddLine(self.itemName, 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("Hearthstone not found", 1, 0.3, 0.3)
        end
        GameTooltip:Show()
    end)
    header.hearthBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)

    -- Clam / Openable Container Button
    header.clamBtn = CreateFrame("Button", nil, header, "SecureActionButtonTemplate")
    header.clamBtn:SetSize(20, 20)
    header.clamBtn:SetPoint("RIGHT", header.hearthBtn, "LEFT", -4, 0)
    header.clamBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.clamBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.clamBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    header.clamBtn.icon = header.clamBtn:CreateTexture(nil, "ARTWORK")
    header.clamBtn.icon:SetAllPoints()
    header.clamBtn.icon:SetTexture("Interface\\Icons\\INV_Box_01")
    header.clamBtn:SetAttribute("type", "item")
    header.clamBtn:Hide()

    header.clamBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        if self.itemName then
            GameTooltip:AddLine("Open Container", 1, 1, 1)
            GameTooltip:AddLine(self.itemName, 0.8, 0.8, 0.8)
        else
            GameTooltip:AddLine("No openable containers found", 1, 0.3, 0.3)
        end
        GameTooltip:Show()
    end)
    header.clamBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)

    -- Options Button
    local optBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    optBtn:SetSize(24, 24)
    optBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    optBtn:SetText("O")
    optBtn:SetScript("OnClick", function()
        if Omni.CategoryEditor then
            Omni.CategoryEditor:Toggle()
        else
            print("Category Editor not loaded")
        end
    end)
    optBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Open Category Editor")
        GameTooltip:Show()
    end)
    optBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    header.optBtn = optBtn

    -- Bag Slots Toggle Button
    local bagSlotsBtn = CreateFrame("Button", nil, header)
    bagSlotsBtn:SetSize(20, 20)
    bagSlotsBtn:SetPoint("RIGHT", optBtn, "LEFT", -6, 0)
    bagSlotsBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bagSlotsBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    bagSlotsBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    bagSlotsBtn.text = bagSlotsBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bagSlotsBtn.text:SetPoint("CENTER")
    bagSlotsBtn.text:SetText("B")
    bagSlotsBtn.text:SetTextColor(1, 0.82, 0)
    bagSlotsBtn:SetScript("OnClick", function()
        if Omni.Data then
            local currentVal = Omni.Data:Get("showBagSlots")
            Omni.Data:Set("showBagSlots", not currentVal)
            Frame:UpdateBagPanelVisibility()
        end
    end)
    bagSlotsBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Toggle Bag Slots Panel")
        GameTooltip:Show()
    end)
    bagSlotsBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
        GameTooltip:Hide()
    end)
    header.bagSlotsBtn = bagSlotsBtn

    -- Character Selector Dropdown Button
    local charBtn = CreateFrame("Button", "OmniInventoryCharBtn", header)
    charBtn:SetSize(90, 18)
    charBtn:SetPoint("LEFT", header.title, "RIGHT", 12, 0)
    charBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    charBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
    charBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    charBtn.text = charBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    charBtn.text:SetPoint("CENTER")
    charBtn.text:SetText(UnitName("player"))

    charBtn:SetScript("OnClick", function(self)
        Frame:ToggleCharacterDropdown(self)
    end)
    charBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.3, 0.3, 1)
    end)
    charBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.2, 0.2, 0.2, 1)
    end)
    header.charBtn = charBtn

    -- Bags/Bank/Keys toggle tabs
    header.bagsTab = CreateFrame("Button", nil, header)
    header.bagsTab:SetSize(38, 18)
    header.bagsTab:SetPoint("LEFT", header.charBtn, "RIGHT", 8, 0)
    header.bagsTab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.bagsTab:SetBackdropColor(0.3, 0.5, 0.3, 1)
    header.bagsTab:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    header.bagsTab.text = header.bagsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.bagsTab.text:SetPoint("CENTER")
    header.bagsTab.text:SetText("Bags")
    header.bagsTab:SetScript("OnClick", function()
        Frame:SetMode("bags")
    end)

    header.bankTab = CreateFrame("Button", nil, header)
    header.bankTab:SetSize(38, 18)
    header.bankTab:SetPoint("LEFT", header.bagsTab, "RIGHT", 2, 0)
    header.bankTab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.bankTab:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.bankTab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    header.bankTab.text = header.bankTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.bankTab.text:SetPoint("CENTER")
    header.bankTab.text:SetText("Bank")
    header.bankTab:SetScript("OnClick", function()
        Frame:SetMode("bank")
    end)

    header.keysTab = CreateFrame("Button", nil, header)
    header.keysTab:SetSize(38, 18)
    header.keysTab:SetPoint("LEFT", header.bankTab, "RIGHT", 2, 0)
    header.keysTab:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    header.keysTab:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.keysTab:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    header.keysTab.text = header.keysTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header.keysTab.text:SetPoint("CENTER")
    header.keysTab.text:SetText("Keys")
    header.keysTab:SetScript("OnClick", function()
        Frame:SetMode("keys")
    end)

    -- Make header draggable
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        mainFrame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        mainFrame:StopMovingOrSizing()
        Frame:SavePosition()
    end)

    mainFrame.header = header
end

-- =============================================================================
-- Search Bar
-- =============================================================================

function Frame:CreateSearchBar()
    local searchBar = CreateFrame("Frame", nil, mainFrame)
    searchBar:SetHeight(SEARCH_HEIGHT)
    searchBar:SetPoint("TOPLEFT", mainFrame.header, "BOTTOMLEFT", 0, -4)
    searchBar:SetPoint("TOPRIGHT", mainFrame.header, "BOTTOMRIGHT", 0, -4)

    -- Background
    searchBar.bg = searchBar:CreateTexture(nil, "BACKGROUND")
    searchBar.bg:SetAllPoints()
    searchBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    searchBar.bg:SetVertexColor(0.1, 0.1, 0.1, 1)

    -- Search icon
    searchBar.icon = searchBar:CreateTexture(nil, "ARTWORK")
    searchBar.icon:SetSize(14, 14)
    searchBar.icon:SetPoint("LEFT", 6, 0)
    searchBar.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")

    -- Search editbox (plain EditBox, no template to avoid white borders)
    searchBar.editBox = CreateFrame("EditBox", "OmniSearchBox", searchBar)
    searchBar.editBox:SetPoint("LEFT", searchBar.icon, "RIGHT", 4, 0)
    searchBar.editBox:SetPoint("RIGHT", -6, 0)
    searchBar.editBox:SetHeight(18)
    searchBar.editBox:SetAutoFocus(false)
    searchBar.editBox:SetFontObject(ChatFontNormal)
    searchBar.editBox:SetTextColor(1, 1, 1, 1)
    searchBar.editBox:SetTextInsets(2, 2, 0, 0)

    searchBar.editBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        Frame:ApplySearch(searchText)
    end)

    searchBar.editBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    mainFrame.searchBar = searchBar
    mainFrame.searchBox = searchBar.editBox
end

-- =============================================================================
-- Quick Filter Bar
-- =============================================================================

local FILTER_HEIGHT = 22
local activeFilter = nil  -- Current active filter

local QUICK_FILTERS = {
    { name = "All", filter = nil },
    { name = "New", filter = "NEW_ITEMS", isSpecial = true },
    { name = "Quest", filter = "Quest" },
    { name = "Gear", filter = "Equipment" },
    { name = "Cons", filter = "Consumable" },
    { name = "Junk", filter = "Junk" },
}

function Frame:CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, mainFrame)
    filterBar:SetHeight(FILTER_HEIGHT)
    filterBar:SetPoint("TOPLEFT", mainFrame.searchBar, "BOTTOMLEFT", 0, -2)
    filterBar:SetPoint("TOPRIGHT", mainFrame.searchBar, "BOTTOMRIGHT", 0, -2)

    -- Background
    filterBar.bg = filterBar:CreateTexture(nil, "BACKGROUND")
    filterBar.bg:SetAllPoints()
    filterBar.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    filterBar.bg:SetVertexColor(0.08, 0.08, 0.08, 1)

    -- Create filter buttons
    filterBar.buttons = {}
    local buttonWidth = 45
    local buttonSpacing = 2
    local startX = 4

    for i, filterInfo in ipairs(QUICK_FILTERS) do
        local btn = CreateFrame("Button", nil, filterBar)
        btn:SetSize(buttonWidth, 18)
        btn:SetPoint("LEFT", startX + (i-1) * (buttonWidth + buttonSpacing), 0)

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
        btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btn.text:SetPoint("CENTER")
        btn.text:SetText(filterInfo.name)

        btn.filterName = filterInfo.filter

        btn:SetScript("OnClick", function(self)
            Frame:SetQuickFilter(self.filterName)
        end)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.25, 0.25, 0.25, 1)
        end)

        btn:SetScript("OnLeave", function(self)
            if activeFilter == self.filterName then
                self:SetBackdropColor(0.2, 0.4, 0.2, 1)
            else
                self:SetBackdropColor(0.15, 0.15, 0.15, 1)
            end
        end)

        filterBar.buttons[i] = btn
    end

    mainFrame.filterBar = filterBar
end

function Frame:SetQuickFilter(filterName)
    activeFilter = filterName

    -- Update button visuals
    if mainFrame.filterBar and mainFrame.filterBar.buttons then
        for _, btn in ipairs(mainFrame.filterBar.buttons) do
            if btn.filterName == activeFilter then
                btn:SetBackdropColor(0.2, 0.4, 0.2, 1)
                btn:SetBackdropBorderColor(0.3, 0.6, 0.3, 1)
            else
                btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
                btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
            end
        end
    end

    -- Apply filter (reuse search highlight logic)
    self:UpdateLayout()
end

function Frame:GetActiveFilter()
    return activeFilter
end

-- =============================================================================
-- Bag Slots Panel
-- =============================================================================

function Frame:CreateBagPanel()
    local bagPanel = CreateFrame("Frame", "OmniInventoryBagPanel", mainFrame)
    bagPanel:SetHeight(38)  -- Fits 28x28 buttons nicely
    bagPanel:SetPoint("TOPLEFT", mainFrame.filterBar, "BOTTOMLEFT", 0, -2)
    bagPanel:SetPoint("TOPRIGHT", mainFrame.filterBar, "BOTTOMRIGHT", 0, -2)

    -- Backdrop
    bagPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bagPanel:SetBackdropColor(0.08, 0.08, 0.08, 1)
    bagPanel:SetBackdropBorderColor(0.18, 0.18, 0.18, 1)

    bagPanel.buttons = {}
    mainFrame.bagPanel = bagPanel
    bagPanel:Hide()
end

function Frame:UpdateBagPanelVisibility()
    if not mainFrame or not mainFrame.bagPanel or not mainFrame.content then return end

    local showBagSlots = OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.showBagSlots
    local shouldShow = showBagSlots and (currentMode ~= "keys")

    mainFrame.content:ClearAllPoints()
    mainFrame.content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PADDING - 20, PADDING + FOOTER_HEIGHT + 4)

    if shouldShow then
        mainFrame.bagPanel:Show()
        mainFrame.content:SetPoint("TOPLEFT", mainFrame.bagPanel, "BOTTOMLEFT", 0, -4)
        self:UpdateBagPanel()
    else
        mainFrame.bagPanel:Hide()
        mainFrame.content:SetPoint("TOPLEFT", mainFrame.filterBar, "BOTTOMLEFT", 0, -4)
    end
end

function Frame:UpdateBagPanel()
    if not mainFrame or not mainFrame.bagPanel or not mainFrame.bagPanel:IsShown() then return end

    local bagPanel = mainFrame.bagPanel

    -- Hide all existing buttons
    for _, btn in ipairs(bagPanel.buttons) do
        btn:Hide()
    end

    local bagsList = {}
    if currentMode == "bank" then
        bagsList = { -1, 5, 6, 7, 8, 9, 10, 11 }
    else
        bagsList = { 0, 1, 2, 3, 4 }
    end

    local size = 28
    local spacing = 6
    local totalWidth = #bagsList * size + (#bagsList - 1) * spacing
    local startX = (bagPanel:GetWidth() - totalWidth) / 2

    for i, bagID in ipairs(bagsList) do
        local btn = bagPanel.buttons[i]
        if not btn then
            btn = CreateFrame("Button", "OmniInventoryBagBtn_" .. i, bagPanel)
            btn:SetSize(size, size)
            
            -- Backdrop
            btn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
            btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

            -- Icon texture
            btn.icon = btn:CreateTexture(nil, "BORDER")
            btn.icon:SetAllPoints()
            btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- Free slot count text
            btn.Count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
            btn.Count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
            btn.Count:SetTextColor(1, 1, 1)

            -- Mouse & Drag registration
            btn:RegisterForClicks("anyUp")
            btn:RegisterForDrag("LeftButton")

            -- Register with Masque if available
            if Omni.MasqueGroup then
                Omni.MasqueGroup:AddButton(btn)
            end

            -- Scripts
            btn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(1, 0.82, 0, 1) -- Golden hover border
                
                -- Highlight items from this bag
                Frame:SetBagHighlight(self.bagID)

                -- Show tooltip
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                if self.bagID == 0 then
                    GameTooltip:SetText(BACKPACK_TOOLTIP, 1, 1, 1)
                    GameTooltip:Show()
                elseif self.bagID == -1 then
                    GameTooltip:SetText(BANK, 1, 1, 1)
                    GameTooltip:Show()
                elseif self.isPurchasable then
                    GameTooltip:SetText(BANK_BAG_PURCHASE, 1, 1, 1)
                    local cost = GetBankSlotCost(GetNumBankSlots())
                    SetTooltipMoney(GameTooltip, cost)
                    GameTooltip:Show()
                else
                    if self.invSlot then
                        local hasItem = GameTooltip:SetInventoryItem("player", self.invSlot)
                        if not hasItem then
                            GameTooltip:SetText(EQUIP_CONTAINER, 1, 1, 1)
                            GameTooltip:Show()
                        end
                    end
                end
            end)

            btn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                Frame:SetBagHighlight(nil)
                GameTooltip:Hide()
            end)

            btn:SetScript("OnClick", function(self, button)
                if Frame:GetViewedCharacter() ~= UnitName("player") then return end
                if self.isPurchasable then
                    PlaySound("igMainMenuOption")
                    StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
                elseif CursorHasItem() then
                    if self.bagID == 0 then
                        PutItemInBackpack()
                    else
                        if self.invSlot then PutItemInBag(self.invSlot) end
                    end
                else
                    -- Toggle or highlight
                end
                Frame:UpdateLayout()
            end)

            btn:SetScript("OnDragStart", function(self)
                if Frame:GetViewedCharacter() ~= UnitName("player") then return end
                if self.bagID ~= 0 and self.bagID ~= -1 and not self.isPurchasable then
                    if self.invSlot then
                        PlaySound("BAGMENUBUTTONPRESS")
                        PickupBagFromSlot(self.invSlot)
                    end
                end
            end)

            btn:SetScript("OnReceiveDrag", function(self)
                if Frame:GetViewedCharacter() ~= UnitName("player") then return end
                if not self.isPurchasable then
                    if self.bagID == 0 then
                        PutItemInBackpack()
                    else
                        if self.invSlot then PutItemInBag(self.invSlot) end
                    end
                end
                Frame:UpdateLayout()
            end)

            bagPanel.buttons[i] = btn
        end

        btn.bagID = bagID
        btn.invSlot = bagID > 0 and ContainerIDToInventoryID(bagID) or nil
        btn.isPurchasable = false

        -- Layout
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", bagPanel, "LEFT", startX + (i - 1) * (size + spacing), 0)
        btn:Show()

        -- Update button state & texture
        if bagID == 0 then
            -- Backpack
            btn.icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
            btn.icon:SetVertexColor(1, 1, 1, 1)
        elseif bagID == -1 then
            -- Bank main
            btn.icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_08")
            btn.icon:SetVertexColor(1, 1, 1, 1)
        else
            -- Check if bank bag slot is purchased
            if bagID >= 5 and bagID <= 11 then
                local numPurchased = GetNumBankSlots()
                local bankSlotIndex = bagID - 4
                if bankSlotIndex > numPurchased then
                    btn.isPurchasable = true
                end
            end

            if btn.isPurchasable then
                btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                btn.icon:SetVertexColor(1, 0.2, 0.2, 0.4) -- Red transparent
            else
                local icon = btn.invSlot and GetInventoryItemTexture("player", btn.invSlot)
                if icon then
                    btn.icon:SetTexture(icon)
                    btn.icon:SetVertexColor(1, 1, 1, 1)
                else
                    btn.icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                    btn.icon:SetVertexColor(1, 1, 1, 0.3) -- Semi-transparent
                end
            end
        end

        -- Update lock state
        if btn.invSlot and IsInventoryItemLocked(btn.invSlot) then
            btn.icon:SetDesaturated(true)
        else
            btn.icon:SetDesaturated(false)
        end

        -- Update slot count
        if not btn.isPurchasable and bagID ~= -1 then
            local total = GetContainerNumSlots(bagID) or 0
            local free = 0
            if total > 0 then
                free = select(1, GetContainerNumFreeSlots(bagID)) or 0
            end
            if total > 0 then
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
end

function Frame:SetBagHighlight(bagID)
    self.highlightedBagID = bagID

    if bagID then
        for _, btn in ipairs(itemButtons) do
            if btn.bagID == bagID then
                -- Highlight
                btn.dimOverlay:Hide()
                
                -- Check usability for correct coloring
                local isUnusable = false
                if btn.itemInfo and btn.itemInfo.hyperlink then
                    if btn.bagID and btn.bagID >= 0 then
                        isUnusable = Omni.API:IsItemUnusable(btn.bagID, btn.slotID)
                    else
                        isUnusable = Omni.API:IsItemUnusableLink(btn.itemInfo.hyperlink)
                    end
                end
                if isUnusable then
                    btn.icon:SetDesaturated(true)
                    btn.icon:SetAlpha(1.0)
                    btn.icon:SetVertexColor(1.0, 0.3, 0.3)
                else
                    btn.icon:SetDesaturated(false)
                    btn.icon:SetAlpha(1.0)
                    btn.icon:SetVertexColor(1, 1, 1)
                end
            else
                -- Dim
                btn.dimOverlay:Show()
                btn.icon:SetDesaturated(true)
                btn.icon:SetAlpha(0.3)
                btn.icon:SetVertexColor(1, 1, 1)
            end
        end

        for _, row in ipairs(listRows) do
            if row:IsShown() and row.itemInfo then
                if row.itemInfo.bagID == bagID then
                    row:SetAlpha(1.0)
                    if row.icon then row.icon:SetDesaturated(false) end
                else
                    row:SetAlpha(0.3)
                    if row.icon then row.icon:SetDesaturated(true) end
                end
            end
        end
    else
        -- Clear highlight (restore search or defaults)
        local searchText = mainFrame.searchBar.editBox:GetText()
        if searchText and searchText ~= "" then
            self:ApplySearch(searchText)
        else
            for _, btn in ipairs(itemButtons) do
                local isUnusable = false
                if btn.itemInfo and btn.itemInfo.hyperlink then
                    if btn.bagID and btn.bagID >= 0 then
                        isUnusable = Omni.API:IsItemUnusable(btn.bagID, btn.slotID)
                    else
                        isUnusable = Omni.API:IsItemUnusableLink(btn.itemInfo.hyperlink)
                    end
                end
                btn.dimOverlay:Hide()
                if isUnusable then
                    btn.icon:SetDesaturated(true)
                    btn.icon:SetAlpha(1.0)
                    btn.icon:SetVertexColor(1.0, 0.3, 0.3)
                else
                    btn.icon:SetDesaturated(false)
                    btn.icon:SetAlpha(1.0)
                    btn.icon:SetVertexColor(1, 1, 1)
                end
            end

            for _, row in ipairs(listRows) do
                if row:IsShown() and row.itemInfo then
                    row:SetAlpha(1.0)
                    if row.icon then row.icon:SetDesaturated(false) end
                end
            end
        end
    end
end

-- =============================================================================
-- Content Area (ScrollFrame)
-- =============================================================================

function Frame:CreateContentArea()
    local content = CreateFrame("ScrollFrame", "OmniContentScroll", mainFrame, "UIPanelScrollFrameTemplate")
    content:SetPoint("TOPLEFT", mainFrame.filterBar, "BOTTOMLEFT", 0, -4)
    content:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PADDING - 20, PADDING + FOOTER_HEIGHT + 4)

    -- Scroll child
    local scrollChild = CreateFrame("Frame", "OmniContentChild", content)
    scrollChild:SetSize(content:GetWidth(), 1)  -- Height set dynamically
    content:SetScrollChild(scrollChild)

    -- Style scrollbar
    local scrollBar = _G["OmniContentScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 20, -16)
        scrollBar:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 20, 16)
    end

    mainFrame.content = content
    mainFrame.scrollChild = scrollChild
end

-- =============================================================================
-- Footer
-- =============================================================================

function Frame:CreateFooter()
    local footer = CreateFrame("Frame", nil, mainFrame)
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)

    -- Background
    footer.bg = footer:CreateTexture(nil, "BACKGROUND")
    footer.bg:SetAllPoints()
    footer.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    footer.bg:SetVertexColor(0.12, 0.12, 0.12, 1)

    -- Bag space counter
    footer.slots = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.slots:SetPoint("LEFT", 6, 0)
    footer.slots:SetText("0/0")

    -- Sell Junk Button
    footer.sellBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    footer.sellBtn:SetSize(80, 20)
    footer.sellBtn:SetPoint("CENTER")
    footer.sellBtn:SetText("Sell Junk")
    footer.sellBtn:Hide()  -- Hidden by default
    footer.sellBtn:SetScript("OnClick", function()
        Frame:SellJunk()
    end)

    -- Money display
    local function FormatTooltipMoney(money)
        local gold = math.floor(money / 10000)
        local silver = math.floor((money % 10000) / 100)
        local copper = money % 100
        return string.format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffb87333%dc|r", gold, silver, copper)
    end

    local moneyFrame = CreateFrame("Frame", nil, footer)
    moneyFrame:SetSize(120, 20)
    moneyFrame:SetPoint("RIGHT", -6, 0)
    moneyFrame:EnableMouse(true)
    footer.moneyFrame = moneyFrame

    footer.money = moneyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    footer.money:SetAllPoints(moneyFrame)
    footer.money:SetJustifyH("RIGHT")
    footer.money:SetText("0g 0s 0c")

    moneyFrame:SetScript("OnEnter", function(self)
        local realmName = GetRealmName()
        local realm = OmniInventoryDB and OmniInventoryDB.realm and OmniInventoryDB.realm[realmName]
        if not realm then return end

        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("Gold Summary", 1, 1, 1)
        GameTooltip:AddLine(" ")

        local totalGold = 0
        local sortedChars = {}
        for charName, charData in pairs(realm) do
            table.insert(sortedChars, { name = charName, gold = charData.gold or 0, class = charData.class })
        end
        table.sort(sortedChars, function(a, b) return a.gold > b.gold end)

        for _, c in ipairs(sortedChars) do
            local color = c.class and RAID_CLASS_COLORS[c.class]
            local colorCode = color and string.format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) or "|cff00ff9a"
            local nameStr = colorCode .. c.name .. "|r"
            GameTooltip:AddDoubleLine(nameStr, FormatTooltipMoney(c.gold))
            totalGold = totalGold + c.gold
        end

        GameTooltip:AddLine("----------------------------------------", 0.5, 0.5, 0.5)
        GameTooltip:AddDoubleLine("|cFFFFFFFFTotal Gold:|r", FormatTooltipMoney(totalGold))
        GameTooltip:Show()
    end)
    
    moneyFrame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    mainFrame.footer = footer
end

-- =============================================================================
-- Resize Handle
-- =============================================================================

function Frame:CreateResizeHandle()
    local handle = CreateFrame("Button", nil, mainFrame)
    handle:SetSize(16, 16)
    handle:SetPoint("BOTTOMRIGHT", -2, 2)
    handle:EnableMouse(true)

    handle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    handle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    handle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    handle:SetScript("OnMouseDown", function()
        mainFrame:StartSizing("BOTTOMRIGHT")
    end)

    handle:SetScript("OnMouseUp", function()
        mainFrame:StopMovingOrSizing()
        Frame:SavePosition()
        Frame:UpdateLayout()
    end)

    mainFrame.resizeHandle = handle
end

-- =============================================================================
-- Event Registration
-- =============================================================================

function Frame:RegisterEvents()
    if not mainFrame then return end

    -- Connect to Event bucket system for bag updates only
    -- Note: Bank events and PLAYER_MONEY are handled by Omni.Events:Init()
    if Omni.Events then
        Omni.Events:RegisterBucketEvent("BAG_UPDATE", function(changedBags)
            if mainFrame:IsShown() and currentMode == "bags" then
                Frame:UpdateLayout(changedBags)
            end
        end)

        -- Merchant events (unique to Frame, not in Events.lua)
        Omni.Events:RegisterEvent("MERCHANT_SHOW", function()
            isMerchantOpen = true
            Frame:UpdateFooterButton()
        end)

        Omni.Events:RegisterEvent("MERCHANT_CLOSED", function()
            isMerchantOpen = false
            Frame:UpdateFooterButton()
        end)
    end
end

-- =============================================================================
-- Position Persistence
-- =============================================================================

function Frame:SavePosition()
    if not mainFrame then return end

    local point, _, _, x, y = mainFrame:GetPoint()
    local width, height = mainFrame:GetSize()

    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.position = {
        point = point,
        x = x,
        y = y,
        width = width,
        height = height,
    }
end

function Frame:LoadPosition()
    if not mainFrame then return end

    local pos = OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.position
    if pos then
        mainFrame:ClearAllPoints()
        mainFrame:SetPoint(pos.point or "CENTER", UIParent, pos.point or "CENTER", pos.x or 0, pos.y or 0)
        if pos.width and pos.height then
            mainFrame:SetSize(pos.width, pos.height)
        end
    end
end

function Frame:SetScale(scale)
    if not mainFrame then return end
    scale = math.max(0.5, math.min(scale or 1, 2.0))
    mainFrame:SetScale(scale)

    -- Save to DB
    OmniInventoryDB = OmniInventoryDB or {}
    OmniInventoryDB.char = OmniInventoryDB.char or {}
    OmniInventoryDB.char.settings = OmniInventoryDB.char.settings or {}
    OmniInventoryDB.char.settings.scale = scale
end

function Frame:ResetPosition()
    if not mainFrame then return end
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:SavePosition()
    self:SetScale(1.0)
end

-- =============================================================================
-- Edit Mode
-- =============================================================================

function Frame:ToggleEditMode()
    editMode = not editMode

    -- Load collapsed categories from SavedVariables
    if editMode then
        collapsedCategories = OmniInventoryDB.char.collapsedCategories or {}
    end

    -- Update button visual
    if mainFrame and mainFrame.header and mainFrame.header.editBtn then
        if editMode then
            mainFrame.header.editBtn:SetBackdropColor(0.4, 0.3, 0.1, 1)
            mainFrame.header.editBtn.text:SetText("Done")
        else
            mainFrame.header.editBtn:SetBackdropColor(0.2, 0.2, 0.2, 1)
            mainFrame.header.editBtn.text:SetText("Edit")
            -- Save collapsed state
            OmniInventoryDB.char.collapsedCategories = collapsedCategories
        end
    end

    -- Force re-render
    self:UpdateLayout()
end

function Frame:IsEditMode()
    return editMode
end

function Frame:ToggleCategoryCollapse(catName)
    if not editMode then return end
    if not catName then return end
    if collapsedCategories[catName] then
        collapsedCategories[catName] = nil
    else
        collapsedCategories[catName] = true
    end
    self:UpdateLayout()
end

function Frame:IsCategoryCollapsed(catName)
    return editMode and collapsedCategories[catName]
end

-- =============================================================================
-- View Modes
-- =============================================================================

function Frame:SetView(mode)
    currentView = mode or "grid"

    if mainFrame and mainFrame.header and mainFrame.header.viewBtn then
        local labels = { grid = "Grid", flow = "Flow", list = "List" }
        mainFrame.header.viewBtn.text:SetText(labels[currentView] or "Grid")
    end

    Frame:UpdateLayout()
end

function Frame:CycleView()
    local modes = { "grid", "flow", "list" }
    local nextIdx = 1

    for i, mode in ipairs(modes) do
        if mode == currentView then
            nextIdx = (i % #modes) + 1
            break
        end
    end

    Frame:SetView(modes[nextIdx])
end

function Frame:CycleSort()
    if not Omni.Sorter then return end

    local modes = Omni.Sorter:GetModes()
    local currentMode = Omni.Sorter:GetDefaultMode()
    local nextIdx = 1

    for i, mode in ipairs(modes) do
        if mode == currentMode then
            nextIdx = (i % #modes) + 1
            break
        end
    end

    local newMode = modes[nextIdx]
    Omni.Sorter:SetDefaultMode(newMode)

    -- Update button tooltip on next hover
    if mainFrame and mainFrame.header and mainFrame.header.sortBtn then
        -- Capitalize first letter for display
        local displayMode = newMode:gsub("^%l", string.upper)
        mainFrame.header.sortBtn.text:SetText(displayMode)
    end

    -- Refresh layout with new sort
    Frame:UpdateLayout()
end

-- =============================================================================
-- Character Selection (Offline View)
-- =============================================================================

local viewedChar = UnitName("player")
local charMenuFrame = CreateFrame("Frame", "OmniInventoryCharMenu", UIParent, "UIDropDownMenuTemplate")

function Frame:GetViewedCharacter()
    return viewedChar or UnitName("player")
end

function Frame:SetViewedCharacter(name)
    viewedChar = name or UnitName("player")

    if mainFrame and mainFrame.header and mainFrame.header.charBtn then
        mainFrame.header.charBtn.text:SetText(viewedChar)
        if viewedChar == UnitName("player") then
            mainFrame.header.charBtn.text:SetTextColor(1, 0.82, 0) -- Gold
            mainFrame.header.title:SetText("|cFF00FF00Omni|r Inventory")
        else
            mainFrame.header.charBtn.text:SetTextColor(0.5, 0.82, 1) -- Light Blue
            mainFrame.header.title:SetText("|cFF00FF00Omni|r (" .. viewedChar .. ")")
        end
    end

    self:UpdateLayout()
end

function Frame:ToggleCharacterDropdown(anchorBtn)
    local realmName = GetRealmName()
    local realm = OmniInventoryDB and OmniInventoryDB.realm and OmniInventoryDB.realm[realmName]
    if not realm then return end

    local menuList = {
        { text = "Select Character", isTitle = true },
    }

    for name, data in pairs(realm) do
        local classColor = "|cff00ff9a"
        if RAID_CLASS_COLORS and data.class and RAID_CLASS_COLORS[data.class] then
            local c = RAID_CLASS_COLORS[data.class]
            classColor = string.format("|cff%02x%02x%02x", c.r*255, c.g*255, c.b*255)
        end

        table.insert(menuList, {
            text = classColor .. name .. "|r",
            func = function()
                self:SetViewedCharacter(name)
            end,
            checked = (viewedChar == name),
        })
    end

    EasyMenu(menuList, charMenuFrame, anchorBtn, 0, 0, "MENU")
end

-- =============================================================================
-- Bags/Bank Mode
-- =============================================================================

--- Set bank open/close state (called by Events.lua)
---@param isOpen boolean
function Frame:SetBankOpen(isOpen)
    isBankOpen = isOpen
    self:UpdateBankTabState()
end

--- Get bank open/close state
---@return boolean isOpen
function Frame:IsBankOpen()
    return isBankOpen
end

function Frame:SetMode(mode)
    currentMode = mode or "bags"
    self:UpdateBankTabState()
    self:UpdateLayout()
end

function Frame:GetMode()
    return currentMode
end

function Frame:UpdateBankTabState()
    if not mainFrame or not mainFrame.header then return end

    local header = mainFrame.header
    if not header.bagsTab or not header.bankTab or not header.keysTab then return end

    -- Reset all tab backdrops to inactive (dark grey)
    header.bagsTab:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.bankTab:SetBackdropColor(0.2, 0.2, 0.2, 1)
    header.keysTab:SetBackdropColor(0.2, 0.2, 0.2, 1)

    if currentMode == "bags" then
        header.bagsTab:SetBackdropColor(0.3, 0.5, 0.3, 1)  -- Active (green tint)
    elseif currentMode == "bank" then
        if isBankOpen then
            header.bankTab:SetBackdropColor(0.3, 0.5, 0.3, 1)  -- Active (green tint)
        else
            header.bankTab:SetBackdropColor(0.5, 0.3, 0.3, 1)  -- Unavailable (red tint)
        end
    elseif currentMode == "keys" then
        header.keysTab:SetBackdropColor(0.3, 0.5, 0.3, 1)  -- Active (green tint)
    end

    -- Show bank unavailable hint
    if currentMode == "bank" and not isBankOpen then
        header.bankTab.text:SetText("Bank*")
    else
        header.bankTab.text:SetText("Bank")
    end
end

-- =============================================================================
-- Dry-Run Optimization
-- =============================================================================
-- Avoids full re-renders when the visual state hasn't actually changed.
-- Derived from BagShui's dry-run pattern (proposedLayoutState vs currentLayoutState).

--- Compute a lightweight fingerprint of current view state
---@return string fingerprint
local function ComputeLayoutState()
    local parts = {}
    parts[#parts + 1] = currentView or "grid"
    parts[#parts + 1] = currentMode or "bags"
    parts[#parts + 1] = isBankOpen and "1" or "0"
    parts[#parts + 1] = searchText or ""
    parts[#parts + 1] = activeFilter or ""
    parts[#parts + 1] = Omni.Sorter and (Omni.Sorter:GetDefaultMode() or "category") or "category"

    -- Include total item count as a content-change proxy
    local totalCount = 0
    if currentMode == "bank" and isBankOpen then
        for bagID = -1, 11 do
            totalCount = totalCount + (GetContainerNumSlots(bagID) or 0)
        end
    elseif currentMode == "keys" then
        totalCount = GetKeyRingSize and GetKeyRingSize() or 0
    else
        for bagID = 0, 4 do
            totalCount = totalCount + (GetContainerNumSlots(bagID) or 0)
        end
    end
    parts[#parts + 1] = totalCount

    return table.concat(parts, "|")
end

--- Check whether a full render is needed based on state diff
---@return boolean needsRender
local function NeedsRender(newState)
    if not DRYRUN_ENABLED then return true end
    if lastLayoutState ~= newState then
        lastLayoutState = newState
        return true
    end
    return false
end

--- Force a full render on next update
function Frame:ForceRender()
    lastLayoutState = nil
    self:UpdateLayout()
end

-- =============================================================================
-- Special Action Buttons (Hearthstone, Clam/Openable)
-- =============================================================================

-- Hearthstone item ID (classic WotLK)
local HEARTHSTONE_ITEM_ID = 6948

--- Scan inventory for openable containers (clams, boxes, etc.)
local function FindOpenableContainer()
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID then
                    -- Check if it's a known openable type using GetItemSpell
                    -- (items with a "Use:" effect that open them)
                    local hasSpell = GetItemSpell and GetItemSpell(link)
                    if hasSpell then
                        -- Verify it's not equipment, gems, or other non-container items
                        local itemType = select(6, GetItemInfo(link))
                        if itemType and itemType ~= "Weapon" and itemType ~= "Armor"
                           and itemType ~= "Gem" and itemType ~= "Recipe"
                           and itemType ~= "Reagent" then
                            return bagID, slot, link
                        end
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

--- Scan for hearthstone in inventory
local function FindHearthstone()
    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slot = 1, numSlots do
            local link = GetContainerItemLink(bagID, slot)
            if link then
                local itemID = tonumber(string.match(link, "item:(%d+)"))
                if itemID == HEARTHSTONE_ITEM_ID then
                    return bagID, slot, link
                end
            end
        end
    end
    return nil, nil, nil
end

--- Update special action buttons based on current inventory
function Frame:UpdateSpecialButtons()
    if not mainFrame or not mainFrame.header then return end

    -- Don't update during combat (secure buttons can't be modified)
    if InCombatLockdown() then return end

    -- Hearthstone button
    local hearthBtn = mainFrame.header.hearthBtn
    if hearthBtn then
        local bagID, slot, link = FindHearthstone()
        if bagID and slot then
            local itemName = GetItemInfo(link or ("item:" .. HEARTHSTONE_ITEM_ID))
            hearthBtn:SetAttribute("bag", bagID)
            hearthBtn:SetAttribute("slot", slot)
            hearthBtn.itemName = itemName or "Hearthstone"
            hearthBtn:Show()

            -- Show cooldown if hearthstone is on cooldown
            if hearthBtn.cooldown then
                local start, duration = GetContainerItemCooldown(bagID, slot)
                if start and start > 0 and duration and duration > 0 then
                    hearthBtn.cooldown:SetCooldown(start, duration)
                    hearthBtn.cooldown:Show()
                else
                    hearthBtn.cooldown:Hide()
                end
            end
        else
            hearthBtn:Hide()
        end
    end

    -- Clam/Openable button
    local clamBtn = mainFrame.header.clamBtn
    if clamBtn then
        local bagID, slot, link = FindOpenableContainer()
        if bagID and slot and link then
            local itemName = GetItemInfo(link)
            clamBtn:SetAttribute("bag", bagID)
            clamBtn:SetAttribute("slot", slot)
            clamBtn.itemName = itemName or "Openable"
            clamBtn:Show()
        else
            clamBtn:Hide()
        end
    end
end

-- =============================================================================
-- Layout Update
-- =============================================================================

function Frame:UpdateLayout(changedBags)
    if not mainFrame or not mainFrame:IsShown() then return end

    -- Dry-run: skip full render if nothing changed
    if Omni.Categorizer then
        local newState = ComputeLayoutState()
        if not NeedsRender(newState) then
            return
        end
    end

    -- Update Bag Slots Panel visibility & positions
    self:UpdateBagPanelVisibility()

    -- Get items based on current mode
    local items = {}
    local activePlayer = UnitName("player")
    local realmName = GetRealmName()

    if viewedChar == activePlayer then
        if OmniC_Container then
            if currentMode == "bank" then
                if isBankOpen then
                    items = OmniC_Container.GetAllBankItems()
                else
                    -- Offline Bank Access
                    items = {}
                    if OmniInventoryDB and OmniInventoryDB.realm then
                        local realm = OmniInventoryDB.realm[realmName]
                        local char = realm and realm[activePlayer]

                        if char and char.bank then
                            for _, savedItem in ipairs(char.bank) do
                                if Omni.API and savedItem.link then
                                    local info = Omni.API:GetExtendedItemInfo(savedItem.link)
                                    if info then
                                        local item = {
                                            iconFileID = info.iconFileID,
                                            itemID = tonumber(string.match(savedItem.link, "item:(%d+)")),
                                            hyperlink = savedItem.link,
                                            stackCount = savedItem.count or 1,
                                            quality = info.quality,
                                            isLocked = false,
                                            isReadable = false,
                                            hasLoot = false,
                                            isBound = true,
                                            bindType = nil,
                                            isFiltered = false,
                                            bagID = -1,
                                            slotID = 0,
                                            itemType = info.itemType,
                                            itemSubType = info.itemSubType,
                                            itemLevel = info.itemLevel,
                                            equipSlot = info.equipSlot,
                                            vendorPrice = info.vendorPrice,
                                        }
                                        table.insert(items, item)
                                    end
                                end
                            end
                        end
                    end
                end
            elseif currentMode == "keys" then
                items = OmniC_Container.GetAllKeyringItems()
            else
                items = OmniC_Container.GetAllBagItems()
            end
        end
    else
        -- OTHER CHARACTER (ALL OFFLINE)
        items = {}
        if OmniInventoryDB and OmniInventoryDB.realm then
            local realm = OmniInventoryDB.realm[realmName]
            local char = realm and realm[viewedChar]
            local savedSource
            if currentMode == "bank" then
                savedSource = char.bank
            elseif currentMode == "keys" then
                savedSource = char.keyring
            else
                savedSource = char.bags
            end

            if savedSource then
                for _, savedItem in ipairs(savedSource) do
                    if Omni.API and savedItem.link then
                        local info = Omni.API:GetExtendedItemInfo(savedItem.link)
                        if info then
                            local item = {
                                iconFileID = info.iconFileID,
                                itemID = tonumber(string.match(savedItem.link, "item:(%d+)")),
                                hyperlink = savedItem.link,
                                stackCount = savedItem.count or 1,
                                quality = info.quality,
                                isLocked = false,
                                isReadable = false,
                                hasLoot = false,
                                isBound = true,
                                bindType = nil,
                                isFiltered = false,
                                bagID = (currentMode == "keys") and -2 or -1,
                                slotID = 0,
                                itemType = info.itemType,
                                itemSubType = info.itemSubType,
                                itemLevel = info.itemLevel,
                                equipSlot = info.equipSlot,
                                vendorPrice = info.vendorPrice,
                            }
                            table.insert(items, item)
                        end
                    end
                end
            end
        end
    end

    -- Categorize items and check for new items
    if Omni.Categorizer then
        for _, item in ipairs(items) do
            item.category = item.category or Omni.Categorizer:GetCategory(item)
            -- Check if this is a new item (acquired this session)
            if item.itemID then
                item.isNew = Omni.Categorizer:IsNewItem(item.itemID)
            end
        end
    end

    -- Apply quick filter (dim non-matching items)
    local quickFilter = self:GetActiveFilter()
    if quickFilter then
        for _, item in ipairs(items) do
            local matches = false

            -- Special filter: NEW_ITEMS - filter by isNew flag
            if quickFilter == "NEW_ITEMS" then
                matches = item.isNew == true
            else
                -- Normal filter: match by category
                if item.category and string.find(item.category, quickFilter) then
                    matches = true
                end
            end

            item.isQuickFiltered = not matches
        end
    else
        -- No filter active - clear all filter flags
        for _, item in ipairs(items) do
            item.isQuickFiltered = false
        end
    end

    -- Sort items
    if Omni.Sorter then
        items = Omni.Sorter:Sort(items, Omni.Sorter:GetDefaultMode())
    end

    -- Render based on view mode
    if currentView == "list" then
        self:RenderListView(items)
    else
        -- Combined Grid/Flow rendering
        self:RenderFlowView(items)
    end

    -- Update footer
    self:UpdateSlotCount()
    self:UpdateMoney()

    -- Update special action buttons (hearthstone, clam)
    self:UpdateSpecialButtons()

    -- Apply search if active
    if searchText and searchText ~= "" then
        self:ApplySearch(searchText)
    end
end

-- =============================================================================
-- Flow/Grid View Rendering
-- =============================================================================

function Frame:RenderFlowView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- Release existing buttons
    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    -- Hide existing headers and list rows
    for _, header in ipairs(categoryHeaders) do header:Hide() end
    for _, row in ipairs(listRows) do row:Hide() end

    -- Group items
    local categories = {}
    local categoryOrder = {}

    if currentView == "grid" then
        -- GRID MODE: Everything in one bucket, sorted by user's preference (already sorted)
        categories["All"] = items
        categoryOrder = { "All" }
    else
        -- FLOW MODE: Group by assigned category
        for _, item in ipairs(items) do
            local cat = item.category or "Miscellaneous"
            if not categories[cat] then
                categories[cat] = {}
                table.insert(categoryOrder, cat)
            end
            table.insert(categories[cat], item)
        end

        -- Sort categories
        if Omni.Categorizer then
            table.sort(categoryOrder, function(a, b)
                local infoA = Omni.Categorizer:GetCategoryInfo(a)
                local infoB = Omni.Categorizer:GetCategoryInfo(b)
                return (infoA.priority or 99) < (infoB.priority or 99)
            end)
        end
    end

    local totalWidth, totalHeight

    if currentView == "grid" then
        -- Layout Constants for Grid View
        local contentWidth = mainFrame.content:GetWidth() - 20
        local columns = math.floor(contentWidth / (ITEM_SIZE + ITEM_SPACING))
        columns = math.max(columns, 1)

        local yOffset = -ITEM_SPACING
        local catItems = categories["All"] or {}

        for i, itemInfo in ipairs(catItems) do
            local btn
            if Omni.Pool then
                btn = Omni.Pool:Acquire("ItemButton")
            else
                btn = Omni.ItemButton:Create(scrollChild)
            end

            if btn then
                btn:SetParent(scrollChild)

                local col = ((i - 1) % columns)
                local row = math.floor((i - 1) / columns)
                local x = ITEM_SPACING + col * (ITEM_SIZE + ITEM_SPACING)
                local y = yOffset - row * (ITEM_SIZE + ITEM_SPACING)

                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", x, y)

                -- Error boundary: Protect against rendering bad items
                local success, err = pcall(function()
                     Omni.ItemButton:SetItem(btn, itemInfo)
                     btn:Show()
                end)

                if not success then
                     Omni.ItemButton:SetItem(btn, nil)
                     if btn.icon then btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                     btn:Show()
                end

                table.insert(itemButtons, btn)
            end
        end

        local catRows = math.ceil(#catItems / columns)
        totalHeight = catRows * (ITEM_SIZE + ITEM_SPACING) + ITEM_SPACING
        totalWidth = contentWidth
    else
        -- FLOW MODE: Pack layout via FlowView packing algorithm
        local maxColumns = OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.columns or 10
        local maxHeight = UIParent:GetHeight() * 0.65 -- 65% of screen height

        local sectionsData, packedWidth, packedHeight = Omni.FlowView:PackLayout(categories, categoryOrder, maxColumns, maxHeight)

        totalWidth = packedWidth
        totalHeight = packedHeight

        local headerIndex = 0
        for _, sec in ipairs(sectionsData) do
            -- Skip collapsed categories in edit mode
            local isCollapsed = editMode and collapsedCategories[sec.name]
            local showItems = not isCollapsed

            -- Render Header
            headerIndex = headerIndex + 1
            local headerFrame = categoryHeaders[headerIndex]
            if not headerFrame then
                headerFrame = CreateFrame("Button", nil, scrollChild)
                headerFrame:SetHeight(HEADER_HEIGHT)
                headerFrame.text = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                headerFrame.text:SetPoint("LEFT", 4, 0)
                headerFrame.text:SetJustifyH("LEFT")
                headerFrame.collapseIcon = headerFrame:CreateTexture(nil, "ARTWORK")
                headerFrame.collapseIcon:SetSize(12, 12)
                headerFrame.collapseIcon:SetPoint("LEFT", 2, 0)
                headerFrame.collapseIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
                headerFrame.collapseIcon:Hide()
                categoryHeaders[headerIndex] = headerFrame
            end

            headerFrame:ClearAllPoints()
            headerFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", sec.x, sec.y)
            headerFrame:SetWidth(sec.width)

            local r, g, b = 1, 1, 1
            if Omni.Categorizer then
                r, g, b = Omni.Categorizer:GetCategoryColor(sec.name)
            end

            -- Update header content
            if editMode then
                headerFrame.text:SetPoint("LEFT", 16, 0)  -- Offset for collapse arrow
                headerFrame.collapseIcon:Show()
                if isCollapsed then
                    headerFrame.collapseIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
                    headerFrame.text:SetText(sec.name .. " (" .. #sec.items .. ") [-]")
                else
                    headerFrame.collapseIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
                    headerFrame.text:SetText(sec.name .. " (" .. #sec.items .. ")")
                end
                headerFrame:SetScript("OnClick", function()
                    Frame:ToggleCategoryCollapse(sec.name)
                end)
                headerFrame:EnableMouse(true)
                headerFrame:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
            else
                headerFrame.collapseIcon:Hide()
                headerFrame.text:SetPoint("LEFT", 4, 0)
                headerFrame.text:SetText(sec.name .. " (" .. #sec.items .. ")")
                headerFrame:SetScript("OnClick", nil)
                headerFrame:EnableMouse(false)
            end

            headerFrame.text:SetTextColor(r, g, b)
            headerFrame:Show()

            -- Render item buttons for this section (skip if collapsed)
            if showItems then
                for i, itemInfo in ipairs(sec.items) do
                    local btn
                    if Omni.Pool then
                        btn = Omni.Pool:Acquire("ItemButton")
                    else
                        btn = Omni.ItemButton:Create(scrollChild)
                    end

                    if btn then
                        btn:SetParent(scrollChild)

                        local pos = sec.itemPositions[i]
                        btn:ClearAllPoints()
                        btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", pos.x, pos.y)

                        local success, err = pcall(function()
                             Omni.ItemButton:SetItem(btn, itemInfo)
                             btn:Show()
                        end)

                        if not success then
                             Omni.ItemButton:SetItem(btn, nil)
                             if btn.icon then btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                             btn:Show()
                        end

                        table.insert(itemButtons, btn)
                    end
                end
            else
                -- Category is collapsed — hide all items but still track the header
                -- Items are simply not rendered
            end
        end

        -- Dynamically adjust main frame width to fit packed columns
        local desiredWidth = totalWidth + PADDING * 2 + 20
        desiredWidth = math.max(desiredWidth, FRAME_MIN_WIDTH)
        mainFrame:SetWidth(desiredWidth)
    end

    scrollChild:SetHeight(totalHeight)
end

-- =============================================================================
-- List View Rendering (Data Table)
-- =============================================================================


function Frame:RenderListView(items)
    if not mainFrame or not mainFrame.scrollChild then return end

    local scrollChild = mainFrame.scrollChild

    -- Release existing item buttons
    if Omni.Pool then
        for _, btn in ipairs(itemButtons) do
            Omni.Pool:Release("ItemButton", btn)
        end
    end
    itemButtons = {}

    -- Hide existing list rows
    for _, row in ipairs(listRows) do
        row:Hide()
    end

    -- Hide category headers if any
    for _, header in ipairs(categoryHeaders) do
        header:Hide()
    end

    -- Layout constants
    local ROW_HEIGHT = 22
    local ICON_SIZE = 18
    local contentWidth = mainFrame.content:GetWidth() - 20
    local yOffset = -4

    for i, itemInfo in ipairs(items) do
        -- Get or create row frame
        local row = listRows[i]
        if not row then
            row = CreateFrame("Button", nil, scrollChild)
            row:SetHeight(ROW_HEIGHT)

            -- Background (alternating)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")

            -- Icon
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(ICON_SIZE, ICON_SIZE)
            row.icon:SetPoint("LEFT", 4, 0)

            -- Name
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.name:SetWidth(180)
            row.name:SetJustifyH("LEFT")

            -- Type
            row.itemType = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.itemType:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
            row.itemType:SetWidth(80)
            row.itemType:SetJustifyH("LEFT")
            row.itemType:SetTextColor(0.7, 0.7, 0.7)

            -- Quantity
            row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.qty:SetPoint("RIGHT", -8, 0)
            row.qty:SetWidth(30)
            row.qty:SetJustifyH("RIGHT")

            -- Hover highlight
            row:SetScript("OnEnter", function(self)
                self.bg:SetVertexColor(0.3, 0.3, 0.3, 1)
                if self.itemInfo and self.itemInfo.bagID and self.itemInfo.slotID then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetBagItem(self.itemInfo.bagID, self.itemInfo.slotID)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                local alpha = (i % 2 == 0) and 0.15 or 0.1
                self.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
                GameTooltip:Hide()
            end)

            -- Click handler
            row:SetScript("OnClick", function(self, mouseButton)
                if self.itemInfo and self.itemInfo.bagID and self.itemInfo.slotID then
                    if mouseButton == "LeftButton" then
                        UseContainerItem(self.itemInfo.bagID, self.itemInfo.slotID)
                    elseif mouseButton == "RightButton" then
                        UseContainerItem(self.itemInfo.bagID, self.itemInfo.slotID)
                    end
                end
            end)

            listRows[i] = row
        end

        -- Position row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)

        -- Set background color (alternating rows)
        if i % 2 == 0 then
            row.bg:SetVertexColor(0.15, 0.15, 0.15, 1)
        else
            row.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
        end

        -- Error boundary
        local success, err = pcall(function()
            -- Set icon
            row.icon:SetTexture(itemInfo.iconFileID or "Interface\\Icons\\INV_Misc_QuestionMark")

            -- Get item info for name and type
            local itemName, _, quality, _, _, itemType, itemSubType = nil, nil, itemInfo.quality, nil, nil, nil, nil
            if itemInfo.hyperlink then
                itemName, _, quality, _, _, itemType, itemSubType = GetItemInfo(itemInfo.hyperlink)
            end

            -- Set name with quality color
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
            local qColor = QUALITY_COLORS[quality or 1] or QUALITY_COLORS[1]
            row.name:SetText(itemName or itemInfo.hyperlink or "Unknown")
            row.name:SetTextColor(qColor[1], qColor[2], qColor[3])

            -- Set type
            row.itemType:SetText(itemSubType or itemType or "")

            -- Set quantity
            local count = itemInfo.stackCount or 1
            if count > 1 then
                row.qty:SetText(count)
            else
                row.qty:SetText("")
            end
        end)

        if not success then
             row.name:SetText("Error loading item")
             row.name:SetTextColor(1, 0, 0)
             row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Store item info for click/tooltip
        row.itemInfo = itemInfo

        row:Show()
        yOffset = yOffset - ROW_HEIGHT
    end

    scrollChild:SetHeight(math.abs(yOffset) + 8)
end

-- =============================================================================
-- Search
-- =============================================================================

function Frame:ApplySearch(text)
    searchText = text or ""
    isSearchActive = (searchText ~= "")

    if not isSearchActive then
        -- Clear search - show all itemButtons
        for _, btn in ipairs(itemButtons) do
            if Omni.ItemButton then
                Omni.ItemButton:ClearSearch(btn)
            end
        end
        -- Show all list rows (they'll be rebuilt on next update anyway)
        for _, row in ipairs(listRows) do
            if row.itemInfo then
                row:SetAlpha(1)
                if row.icon then row.icon:SetDesaturated(false) end
            end
        end
        return
    end

    local lowerSearch = string.lower(searchText)

    -- Filter Grid/Flow view buttons
    for _, btn in ipairs(itemButtons) do
        local itemInfo = btn.itemInfo
        local isMatch = false

        if itemInfo and itemInfo.hyperlink then
            local name = GetItemInfo(itemInfo.hyperlink)
            if name and string.find(string.lower(name), lowerSearch, 1, true) then
                isMatch = true
            end
        end

        if Omni.ItemButton then
            Omni.ItemButton:SetSearchMatch(btn, isMatch)
        end
    end

    -- Filter List view rows
    for _, row in ipairs(listRows) do
        if row:IsShown() and row.itemInfo then
            local itemInfo = row.itemInfo
            local isMatch = false

            if itemInfo.hyperlink then
                local name = GetItemInfo(itemInfo.hyperlink)
                if name and string.find(string.lower(name), lowerSearch, 1, true) then
                    isMatch = true
                end
            end

            if isMatch then
                row:SetAlpha(1)
                if row.icon then row.icon:SetDesaturated(false) end
            else
                row:SetAlpha(0.3)
                if row.icon then row.icon:SetDesaturated(true) end
            end
        end
    end
end

-- =============================================================================
-- Footer Updates
-- =============================================================================

function Frame:UpdateSlotCount()
    if not mainFrame or not mainFrame.footer then return end

    if viewedChar ~= UnitName("player") then
        local realmName = GetRealmName()
        local realm = OmniInventoryDB and OmniInventoryDB.realm and OmniInventoryDB.realm[realmName]
        local char = realm and realm[viewedChar]
        local count = 0
        if char then
            local savedSource
            if currentMode == "bank" then
                savedSource = char.bank
            elseif currentMode == "keys" then
                savedSource = char.keyring
            else
                savedSource = char.bags
            end
            count = savedSource and #savedSource or 0
        end
        if currentMode == "keys" then
            mainFrame.footer.slots:SetText(string.format("%d Keys", count))
        else
            mainFrame.footer.slots:SetText(string.format("%d Items", count))
        end
        return
    end

    local free, total = 0, 0

    if currentMode == "bank" then
        -- Main bank container (bagID = -1)
        local mainSlots = GetContainerNumSlots(-1) or 0
        local mainFree = GetContainerNumFreeSlots(-1) or 0
        total = total + mainSlots
        free = free + mainFree

        -- Bank bags (5-11)
        for bagID = 5, 11 do
            local numSlots = GetContainerNumSlots(bagID) or 0
            local numFree = GetContainerNumFreeSlots(bagID) or 0
            total = total + numSlots
            free = free + numFree
        end
        local used = total - free
        mainFrame.footer.slots:SetText(string.format("%d/%d", used, total))
    elseif currentMode == "keys" then
        -- Keyring container (bagID = -2)
        total = GetKeyRingSize and GetKeyRingSize() or 0
        if total > 0 then
            free = select(1, GetContainerNumFreeSlots(-2)) or 0
        end
        local used = total - free
        mainFrame.footer.slots:SetText(string.format("%d/%d Keys", used, total))
    else
        -- Regular bags (0-4)
        for bagID = 0, 4 do
            local numSlots = GetContainerNumSlots(bagID) or 0
            local numFree = GetContainerNumFreeSlots(bagID) or 0
            total = total + numSlots
            free = free + numFree
        end
        local used = total - free
        mainFrame.footer.slots:SetText(string.format("%d/%d", used, total))
    end
end

function Frame:UpdateMoney()
    if not mainFrame or not mainFrame.footer then return end

    if currentMode == "keys" then
        if mainFrame.footer.moneyFrame then mainFrame.footer.moneyFrame:Hide() end
        return
    else
        if mainFrame.footer.moneyFrame then mainFrame.footer.moneyFrame:Show() end
    end

    local money = 0
    if viewedChar == UnitName("player") then
        money = GetMoney() or 0
    else
        local realmName = GetRealmName()
        local realm = OmniInventoryDB and OmniInventoryDB.realm and OmniInventoryDB.realm[realmName]
        local char = realm and realm[viewedChar]
        money = char and char.gold or 0
    end

    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100

    mainFrame.footer.money:SetText(string.format("%dg %ds %dc", gold, silver, copper))
end

function Frame:UpdateFooterButton()
    if not mainFrame or not mainFrame.footer or not mainFrame.footer.sellBtn then return end

    if isMerchantOpen then
        mainFrame.footer.sellBtn:Show()
    else
        mainFrame.footer.sellBtn:Hide()
    end
end

-- =============================================================================
-- Sell Junk Logic
-- =============================================================================

function Frame:SellJunk()
    if not isMerchantOpen then return end

    local totalValue = 0
    local sellCount = 0

    for bagID = 0, 4 do
        local numSlots = GetContainerNumSlots(bagID)
        for slotID = 1, numSlots do
            local texture, count, locked, quality, readable, lootable, link = GetContainerItemInfo(bagID, slotID)
            if link and (quality == 0) and not locked then -- 0 is Poor/Grey and not locked
                local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(link)
                if vendorPrice and vendorPrice > 0 then
                    UseContainerItem(bagID, slotID)
                    totalValue = totalValue + (vendorPrice * (count or 1))
                    sellCount = sellCount + 1
                end
            end
        end
    end

    if sellCount > 0 then
        local gold = math.floor(totalValue / 10000)
        local silver = math.floor((totalValue % 10000) / 100)
        local copper = totalValue % 100
        print(string.format("|cFF00FF00OmniInventory|r: Sold %d junk items for %dg %ds %dc", sellCount, gold, silver, copper))
    else
        print("|cFF00FF00OmniInventory|r: No junk to sell.")
    end
end

-- =============================================================================
-- Show/Hide/Toggle
-- =============================================================================

function Frame:Show()
    if not mainFrame then
        self:CreateMainFrame()
        self:LoadPosition()
    end

    mainFrame:Show()
    self:UpdateLayout()
end

function Frame:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function Frame:Toggle()
    if mainFrame and mainFrame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

-- =============================================================================
-- Auto-Sort Physical Bags
-- =============================================================================

function Frame:PhysicalSortBags()
    if Omni.Sorter then
        local isBank = (currentMode == "bank")
        Omni.Sorter:PhysicalSort(isBank)
    end
end

function Frame:IsShown()
    return mainFrame and mainFrame:IsShown()
end

-- =============================================================================
-- Initialization
-- =============================================================================

function Frame:Init()
    -- Frame is created on first show
end

print("|cFF00FF00OmniInventory|r: Frame loaded")
