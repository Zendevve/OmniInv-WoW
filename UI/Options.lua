-- =============================================================================
-- OmniInventory Configuration Panel
-- =============================================================================
-- Purpose: Simple standalone options frame called via /oi config
-- Features: Scale slider, Sort mode, View mode, Reset position, Live Preview
-- =============================================================================

local addonName, Omni = ...

Omni.Settings = {}
local Settings = Omni.Settings
local optionsFrame = nil
local previewFrame = nil

-- =============================================================================
-- Preview Panel (Live Layout Preview)
-- =============================================================================

local PREVIEW_WIDTH = 220
local PREVIEW_HEIGHT = 150
local PREVIEW_ITEM_SIZE = 12
local PREVIEW_SPACING = 2

local function RenderPreview()
    if not previewFrame then return end

    -- Clear existing preview items
    if previewFrame.items then
        for _, item in ipairs(previewFrame.items) do
            item:Hide()
            item:SetParent(nil)
        end
    end
    previewFrame.items = {}

    -- Get current settings
    local viewMode = OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.viewMode or "grid"
    local sortMode = OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.sortMode or "category"
    local columns = OmniInventoryDB and OmniInventoryDB.global and OmniInventoryDB.global.columns or 10

    -- Sample items (synthetic preview data)
    local sampleItems = {}
    local colors = { 0.6, 0.4, 0.2, 0.8, 1.0, 0.3, 0.7, 0.5 }
    for i = 1, 24 do
        sampleItems[i] = {
            color = colors[(i % #colors) + 1],
            label = tostring(i),
        }
    end

    if viewMode == "grid" then
        -- Grid view: simple columns
        local cols = math.min(columns, 8)
        for i, item in ipairs(sampleItems) do
            local btn = previewFrame:CreateTexture(nil, "ARTWORK")
            btn:SetTexture(item.color * 0.3, item.color * 0.5, item.color * 0.7, 0.8)
            btn:SetSize(PREVIEW_ITEM_SIZE, PREVIEW_ITEM_SIZE)
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            btn:SetPoint("TOPLEFT", previewFrame, "TOPLEFT",
                8 + col * (PREVIEW_ITEM_SIZE + PREVIEW_SPACING),
                -8 - row * (PREVIEW_ITEM_SIZE + PREVIEW_SPACING))
            btn:Show()
            table.insert(previewFrame.items, btn)
        end

    elseif viewMode == "flow" then
        -- Flow view: sections with headers
        local sectionCount = 3
        local itemsPerSection = math.floor(#sampleItems / sectionCount)
        local xOffset = 8
        local yOffset = -8

        for sec = 1, sectionCount do
            -- Section header
            local header = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetFont(header:GetFont(), 7)
            header:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", xOffset, yOffset)
            header:SetText("Category " .. sec)
            header:SetTextColor(1, 0.8, 0.2)
            yOffset = yOffset - 10

            -- Items in section
            local startIdx = (sec - 1) * itemsPerSection + 1
            local endIdx = math.min(sec * itemsPerSection, #sampleItems)
            local cols = 6

            for i = startIdx, endIdx do
                local item = sampleItems[i]
                local btn = previewFrame:CreateTexture(nil, "ARTWORK")
                btn:SetTexture(item.color * 0.3, item.color * 0.5, item.color * 0.7, 0.8)
                btn:SetSize(PREVIEW_ITEM_SIZE, PREVIEW_ITEM_SIZE)
                local idx = i - startIdx
                local col = idx % cols
                local row = math.floor(idx / cols)
                btn:SetPoint("TOPLEFT", previewFrame, "TOPLEFT",
                    xOffset + col * (PREVIEW_ITEM_SIZE + PREVIEW_SPACING),
                    yOffset - row * (PREVIEW_ITEM_SIZE + PREVIEW_SPACING))
                btn:Show()
                table.insert(previewFrame.items, btn)
            end

            local rows = math.ceil((endIdx - startIdx + 1) / cols)
            yOffset = yOffset - rows * (PREVIEW_ITEM_SIZE + PREVIEW_SPACING) - 6

            -- Start new column if needed
            if sec == 1 then
                xOffset = xOffset + 80
                yOffset = -8
            end
        end

    elseif viewMode == "list" then
        -- List view: single column rows
        for i, item in ipairs(sampleItems) do
            local row = previewFrame:CreateTexture(nil, "ARTWORK")
            row:SetTexture(0.15, 0.15, 0.15, 0.6)
            row:SetSize(PREVIEW_WIDTH - 16, 8)
            row:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 8, -8 - (i - 1) * 10)

            local icon = previewFrame:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(item.color * 0.3, item.color * 0.5, item.color * 0.7, 0.8)
            icon:SetSize(8, 8)
            icon:SetPoint("LEFT", row, "LEFT", 2, 0)

            local label = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            label:SetFont(label:GetFont(), 6)
            label:SetPoint("LEFT", icon, "RIGHT", 2, 0)
            label:SetText("Item " .. item.label)
            label:SetTextColor(0.8, 0.8, 0.8)

            row:Show()
            icon:Show()
            label:Show()
            table.insert(previewFrame.items, row)
            table.insert(previewFrame.items, icon)
            table.insert(previewFrame.items, label)
        end
    end

    -- Update preview label
    if previewFrame.label then
        previewFrame.label:SetText(viewMode:upper() .. " View (" .. sortMode .. ")")
    end
end

-- =============================================================================
-- Creation
-- =============================================================================

function Settings:CreateOptionsFrame()
    if optionsFrame then return optionsFrame end

    optionsFrame = CreateFrame("Frame", "OmniOptionsFrame", UIParent)
    optionsFrame:SetSize(300, 560)
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:EnableMouse(true)
    optionsFrame:SetMovable(true)
    optionsFrame:SetClampedToScreen(true)

    -- Backdrop
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })

    -- Draggable header
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)

    -- Title
    local title = optionsFrame:CreateTexture(nil, "ARTWORK")
    title:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
    title:SetSize(300, 64)
    title:SetPoint("TOP", 0, 12)

    local titleText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", title, "TOP", 0, -14)
    titleText:SetText("OmniInventory Settings")

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, optionsFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Content Container
    local content = CreateFrame("Frame", nil, optionsFrame)
    content:SetPoint("TOPLEFT", 16, -40)
    content:SetPoint("BOTTOMRIGHT", -16, 16)

    self.content = content
    self:CreateControls(content)

    optionsFrame:Hide()
    return optionsFrame
end

function Settings:CreateControls(parent)
    local yOffset = -20
    local SPACING = 40

    -- 1. Scale Slider
    local scaleSlider = CreateFrame("Slider", "OmniScaleSlider", parent, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOP", 0, yOffset)
    scaleSlider:SetMinMaxValues(0.5, 2.0)
    scaleSlider:SetValueStep(0.1)
    -- Note: SetObeyStepOnDrag not available in WotLK 3.3.5a
    scaleSlider:SetWidth(200)

    _G[scaleSlider:GetName() .. "Low"]:SetText("50%")
    _G[scaleSlider:GetName() .. "High"]:SetText("200%")
    _G[scaleSlider:GetName() .. "Text"]:SetText("Frame Scale")

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        -- Round to 1 decimal
        value = math.floor(value * 10 + 0.5) / 10
        if Omni.Frame then
            Omni.Frame:SetScale(value)
        end
    end)
    self.scaleSlider = scaleSlider

    yOffset = yOffset - SPACING - 20

    -- 2. View Mode (Grid, Flow, List)
    self:CreateLabel(parent, "View Mode", 0, yOffset)
    yOffset = yOffset - 20

    local viewBtn = CreateFrame("Button", "OmniViewToggle", parent, "UIPanelButtonTemplate")
    viewBtn:SetSize(140, 24)
    viewBtn:SetPoint("TOP", 0, yOffset)
    viewBtn:SetText("Cycle View")
    viewBtn:SetScript("OnClick", function()
        if Omni.Frame then Omni.Frame:CycleView() end
        RenderPreview()
    end)
    self.viewBtn = viewBtn

    yOffset = yOffset - SPACING

    -- 3. Sort Mode
    self:CreateLabel(parent, "Sort Mode (Default)", 0, yOffset)
    yOffset = yOffset - 20

    local sortBtn = CreateFrame("Button", "OmniSortToggle", parent, "UIPanelButtonTemplate")
    sortBtn:SetSize(140, 24)
    sortBtn:SetPoint("TOP", 0, yOffset)
    sortBtn:SetText("Cycle Sort")
    sortBtn:SetScript("OnClick", function()
        if Omni.Frame then Omni.Frame:CycleSort() end
        RenderPreview()
    end)
    self.sortBtn = sortBtn

    yOffset = yOffset - SPACING - 20

    -- 4. Live Preview Panel
    self:CreateLabel(parent, "Layout Preview", 0, yOffset)
    yOffset = yOffset - 18

    previewFrame = CreateFrame("Frame", nil, parent)
    previewFrame:SetSize(PREVIEW_WIDTH, PREVIEW_HEIGHT)
    previewFrame:SetPoint("TOP", 0, yOffset)
    previewFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    previewFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
    previewFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    previewFrame.items = {}

    previewFrame.label = previewFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewFrame.label:SetPoint("TOP", previewFrame, "TOP", 0, -4)
    previewFrame.label:SetText("GRID View (category)")
    previewFrame.label:SetTextColor(0.8, 0.8, 0.6)

    yOffset = yOffset - PREVIEW_HEIGHT - 16

    -- 5. Category Editor Button
    local catBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    catBtn:SetSize(160, 24)
    catBtn:SetPoint("TOP", 0, yOffset)
    catBtn:SetText("Open Category Editor")
    catBtn:SetScript("OnClick", function()
        if Omni.CategoryEditor then
            Omni.CategoryEditor:Toggle()
        else
            print("|cFF00FF00OmniInventory|r: Category Editor not loaded")
        end
    end)
    self.catBtn = catBtn

    yOffset = yOffset - SPACING - 10

    -- 6. Reset Button
    local resetBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    resetBtn:SetSize(160, 24)
    resetBtn:SetPoint("TOP", 0, yOffset)
    resetBtn:SetText("Reset Position & Scale")
    resetBtn:SetScript("OnClick", function()
        if Omni.Frame then
            Omni.Frame:ResetPosition()
            if self.scaleSlider then self.scaleSlider:SetValue(1.0) end
        end
    end)

    yOffset = yOffset - SPACING - 10

    -- 7. Export Button
    local exportBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    exportBtn:SetSize(160, 24)
    exportBtn:SetPoint("TOP", 0, yOffset)
    exportBtn:SetText("Export Profile")
    exportBtn:SetScript("OnClick", function()
        if Omni.Data then
            Omni.Data:ShareProfile()
        end
    end)
    exportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Export Profile", 1, 1, 1)
        GameTooltip:AddLine("Prints profile string to chat for sharing", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    exportBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    yOffset = yOffset - 30

    -- 8. Import Button
    local importBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    importBtn:SetSize(160, 24)
    importBtn:SetPoint("TOP", 0, yOffset)
    importBtn:SetText("Import Profile")
    importBtn:SetScript("OnClick", function()
        -- Show input dialog for profile string
        local dialog = CreateFrame("Frame", "OmniInvImportDialog", UIParent, "BasicFrameTemplateWithEditBox")
        dialog:SetSize(400, 200)
        dialog:SetPoint("CENTER")
        dialog:SetFrameStrata("DIALOG")
        dialog:EnableMouse(true)
        dialog:SetMovable(true)
        dialog:RegisterForDrag("LeftButton")
        dialog:SetScript("OnDragStart", dialog.StartMoving)
        dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)

        dialog.Title:SetText("Import OmniInventory Profile")

        dialog.EditBox:SetMultiLine(true)
        dialog.EditBox:SetAutoFocus(true)
        dialog.EditBox:SetFontObject(GameFontHighlight)
        dialog.EditBox:SetTextInsets(8, 8, 8, 8)

        local importBtn2 = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        importBtn2:SetSize(100, 24)
        importBtn2:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -10, 20)
        importBtn2:SetText("Import")
        importBtn2:SetScript("OnClick", function()
            local profileStr = dialog.EditBox:GetText()
            if profileStr and profileStr ~= "" then
                local ok, err = Omni.Data:ImportProfile(profileStr)
                if ok then
                    print("|cFF00FF00OmniInventory|r: Profile imported successfully!")
                else
                    print("|cFFFF0000OmniInventory|r: Import failed: " .. (err or "unknown error"))
                end
                dialog:Hide()
            end
        end)

        local cancelBtn = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        cancelBtn:SetSize(100, 24)
        cancelBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 10, 20)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

        dialog:Show()
    end)
    importBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Import Profile", 1, 1, 1)
        GameTooltip:AddLine("Paste a profile string from another character/player", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    importBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function Settings:CreateLabel(parent, text, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("TOP", x, y)
    label:SetText(text)
    return label
end

-- =============================================================================
-- Actions
-- =============================================================================

function Settings:Toggle()
    if not optionsFrame then
        self:CreateOptionsFrame()
    end

    if optionsFrame:IsShown() then
        optionsFrame:Hide()
    else
        self:UpdateValues()
        RenderPreview()
        optionsFrame:Show()
    end
end

function Settings:UpdateValues()
    if not optionsFrame then return end

    -- Sync slider with current scale
    if OmniInventoryDB and OmniInventoryDB.char and OmniInventoryDB.char.settings then
        local scale = OmniInventoryDB.char.settings.scale or 1
        self.scaleSlider:SetValue(scale)
    end
end

function Settings:Init()
    -- Initialized
end

print("|cFF00FF00OmniInventory|r: Settings module loaded")
