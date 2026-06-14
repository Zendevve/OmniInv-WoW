local addonName, OI = ...
OI.Frame = {}
local Frame = OI.Frame

local FRAME_MIN_WIDTH = 350
local FRAME_MIN_HEIGHT = 300
local FRAME_DEFAULT_WIDTH = 450
local FRAME_DEFAULT_HEIGHT = 400
local HEADER_HEIGHT = 24
local FOOTER_HEIGHT = 24
local SEARCH_HEIGHT = 24
local FILTER_HEIGHT = 22
local PADDING = 8
local ITEM_SIZE = 37
local ITEM_SPACING = 4
local SECTION_SPACING = 8
local SLOT_SIZE = 28
local SLOT_SPACING = 6

local mainFrame = nil
local itemButtons = {}
local categoryHeaders = {}
local listRows = {}
local currentView = "grid"
local currentMode = "bags"
local isBankOpen = false
local isMerchantOpen = false
local searchText = ""
local activeFilter = nil
local editMode = false
local collapsedCategories = {}
local viewedChar = UnitName("player")
local lastLayoutState = nil
local DRYRUN_ENABLED = true

local QUICK_FILTERS = {
    { name = "All", filter = nil },
    { name = "New", filter = "NEW_ITEMS", isSpecial = true },
    { name = "Quest", filter = "Quest" },
    { name = "Gear", filter = "Equipment" },
    { name = "Cons", filter = "Consumable" },
    { name = "Junk", filter = "Junk" }
}

local function ComputeLayoutState()
    local sortMode = OI.db and OI.db.global and OI.db.global.sortMode or "name"
    local totalSlots = 0
    if currentMode == "bags" then
        for bag = 0, 4 do
            totalSlots = totalSlots + (GetContainerNumSlots(bag) or 0)
        end
    elseif currentMode == "bank" then
        for bag = -1, 11 do
            totalSlots = totalSlots + (GetContainerNumSlots(bag) or 0)
        end
    elseif currentMode == "keys" then
        totalSlots = GetKeyRingSize and GetKeyRingSize() or 0
    end
    local state = strjoin("|",
        currentView or "",
        currentMode or "",
        tostring(isBankOpen),
        searchText or "",
        activeFilter or "",
        sortMode,
        tostring(totalSlots)
    )
    return state
end

local function NeedsRender(newState)
    if not DRYRUN_ENABLED then return true end
    if newState == lastLayoutState then return false end
    return true
end

function Frame:ForceRender()
    lastLayoutState = nil
end

local function CreateMainFrame()
    mainFrame = CreateFrame("Frame", "OmniInventoryContainer", UIParent, "BackdropTemplate")
    mainFrame:SetSize(FRAME_DEFAULT_WIDTH, FRAME_DEFAULT_HEIGHT)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetClampedToScreen(true)
    mainFrame:SetResizable(true)
    mainFrame:SetMinResize(FRAME_MIN_WIDTH, FRAME_MIN_HEIGHT)
    mainFrame:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Tooltips\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    mainFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    mainFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    tinsert(UISpecialFrames, "OmniInventoryContainer")
    mainFrame:SetFrameStrata("HIGH")
    mainFrame:SetFrameLevel(10)
    mainFrame:EnableMouse(true)
    mainFrame:SetMovable(true)
    Frame.mainFrame = mainFrame
    Frame:CreateHeader()
    Frame:CreateSearchBar()
    Frame:CreateFilterBar()
    Frame:CreateBagPanel()
    Frame:CreateContentArea()
    Frame:CreateFooter()
    Frame:CreateResizeHandle()
    mainFrame.fadeElapsed = 0
    mainFrame:SetScript("OnShow", function(self)
        self.fadeElapsed = 0
        self:SetAlpha(0)
        self:SetScript("OnUpdate", function(frame, elapsed)
            frame.fadeElapsed = frame.fadeElapsed + elapsed
            local alpha = math.min(frame.fadeElapsed / 0.15, 1)
            frame:SetAlpha(alpha)
            if alpha >= 1 then
                frame:SetScript("OnUpdate", nil)
            end
        end)
        if OI.db and OI.db.char and OI.db.char.settings then
            Frame:SetScale(OI.db.char.settings.scale or 1)
        end
        Frame:LoadPosition()
        Frame:UpdateLayout()
    end)
    mainFrame:SetScript("OnHide", function(self)
        if OI.db and OI.db.char and OI.db.char.settings and OI.db.char.settings.autoSortOnClose then
            Frame:PhysicalSortBags()
        end
    end)
    if OI.db and OI.db.char and OI.db.char.position then
        Frame:LoadPosition()
    end
end

local function CreateHeader()
    local header = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    header:SetHeight(HEADER_HEIGHT)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", 0, 0)
    header:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    header:SetBackdropColor(0.05, 0.05, 0.05, 1)
    header:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    header:EnableMouse(true)
    header:SetMovable(true)
    header:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mainFrame:StartMoving()
        end
    end)
    header:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            mainFrame:StopMovingOrSizing()
            Frame:SavePosition()
        end
    end)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 8, 0)
    title:SetText("|cFF00FF00Omni|r Inventory")
    title:SetFont("Fonts\ARIALN.TTF", 12, "OUTLINE")
    header.title = title
    local closeBtn = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    closeBtn:SetSize(HEADER_HEIGHT - 4, HEADER_HEIGHT - 4)
    closeBtn:SetPoint("RIGHT", -2, 0)
    closeBtn:SetScript("OnClick", function()
        Frame:Hide()
    end)
    header.closeBtn = closeBtn
    local viewBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    viewBtn:SetSize(50, HEADER_HEIGHT - 4)
    viewBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)
    viewBtn:SetText("Grid")
    viewBtn:SetScript("OnClick", function()
        Frame:CycleView()
    end)
    header.viewBtn = viewBtn
    local sortBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    sortBtn:SetSize(50, HEADER_HEIGHT - 4)
    sortBtn:SetPoint("RIGHT", viewBtn, "LEFT", -2, 0)
    sortBtn:SetText("Sort")
    sortBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    sortBtn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            Frame:PhysicalSortBags()
        else
            Frame:CycleSort()
        end
    end)
    header.sortBtn = sortBtn
    local editBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    editBtn:SetSize(50, HEADER_HEIGHT - 4)
    editBtn:SetPoint("RIGHT", sortBtn, "LEFT", -2, 0)
    editBtn:SetText("Edit")
    editBtn:SetScript("OnClick", function()
        Frame:ToggleEditMode()
    end)
    header.editBtn = editBtn
    local hearthBtn = CreateFrame("Button", nil, header, "SecureActionButtonTemplate,BackdropTemplate")
    hearthBtn:SetSize(HEADER_HEIGHT - 4, HEADER_HEIGHT - 4)
    hearthBtn:SetPoint("RIGHT", editBtn, "LEFT", -4, 0)
    hearthBtn:SetNormalTexture("Interface\Icons\INV_Misc_Rune_01")
    hearthBtn:SetHighlightTexture("Interface\Buttons\UI-Common-MouseHilight", "ADD")
    hearthBtn:SetAttribute("type", "spell")
    hearthBtn:SetAttribute("spell", nil)
    hearthBtn:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    hearthBtn:SetBackdropColor(0, 0, 0, 0.5)
    hearthBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local cooldown = CreateFrame("Cooldown", nil, hearthBtn, "CooldownFrameTemplate")
    cooldown:SetAllPoints()
    hearthBtn.cooldown = cooldown
    header.hearthBtn = hearthBtn
    local charBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    charBtn:SetSize(80, HEADER_HEIGHT - 4)
    charBtn:SetPoint("LEFT", header, "LEFT", title:GetStringWidth() + 16, 0)
    charBtn:SetText(viewedChar or UnitName("player"))
    charBtn:SetScript("OnClick", function(self)
        Frame:ToggleCharacterDropdown(self)
    end)
    header.charBtn = charBtn
    local bagsTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    bagsTab:SetSize(60, HEADER_HEIGHT - 4)
    bagsTab:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 4, -2)
    bagsTab:SetText("Bags")
    bagsTab:SetScript("OnClick", function()
        Frame:SetMode("bags")
    end)
    header.bagsTab = bagsTab
    local bankTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    bankTab:SetSize(60, HEADER_HEIGHT - 4)
    bankTab:SetPoint("LEFT", bagsTab, "RIGHT", 2, 0)
    bankTab:SetText("Bank")
    bankTab:SetScript("OnClick", function()
        Frame:SetMode("bank")
    end)
    header.bankTab = bankTab
    local keysTab = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    keysTab:SetSize(60, HEADER_HEIGHT - 4)
    keysTab:SetPoint("LEFT", bankTab, "RIGHT", 2, 0)
    keysTab:SetText("Keys")
    keysTab:SetScript("OnClick", function()
        Frame:SetMode("keys")
    end)
    header.keysTab = keysTab
    Frame.header = header
    Frame:UpdateBankTabState()
end

local function CreateSearchBar()
    local searchFrame = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    searchFrame:SetHeight(SEARCH_HEIGHT)
    searchFrame:SetPoint("TOPLEFT", Frame.header, "BOTTOMLEFT", PADDING, -2)
    searchFrame:SetPoint("TOPRIGHT", Frame.header, "BOTTOMRIGHT", -PADDING, -2)
    searchFrame:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    searchFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    searchFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local searchIcon = searchFrame:CreateTexture(nil, "OVERLAY")
    searchIcon:SetSize(SEARCH_HEIGHT - 4, SEARCH_HEIGHT - 4)
    searchIcon:SetPoint("LEFT", 4, 0)
    searchIcon:SetTexture("Interface\Icons\INV_MagnifyingGlass")
    searchIcon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    local editBox = CreateFrame("EditBox", nil, searchFrame)
    editBox:SetPoint("LEFT", searchIcon, "RIGHT", 4, 0)
    editBox:SetPoint("RIGHT", -8, 0)
    editBox:SetHeight(SEARCH_HEIGHT)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        Frame:ApplySearch(searchText)
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    local placeholder = searchFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    placeholder:SetText("Search...")
    placeholder:Hide()
    editBox:SetScript("OnEditFocusGained", function(self)
        placeholder:Hide()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            placeholder:Show()
        end
    end)
    if editBox:GetText() == "" then
        placeholder:Show()
    end
    searchFrame.editBox = editBox
    searchFrame.searchIcon = searchIcon
    searchFrame.placeholder = placeholder
    Frame.searchFrame = searchFrame
end

local function CreateFilterBar()
    local filterBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    filterBar:SetHeight(FILTER_HEIGHT)
    filterBar:SetPoint("TOPLEFT", Frame.searchFrame, "BOTTOMLEFT", 0, -2)
    filterBar:SetPoint("TOPRIGHT", Frame.searchFrame, "BOTTOMRIGHT", 0, -2)
    local filterButtons = {}
    local xOffset = 4
    for i, filter in ipairs(QUICK_FILTERS) do
        local btn = CreateFrame("Button", nil, filterBar, "UIPanelButtonTemplate")
        btn:SetSize(60, FILTER_HEIGHT - 2)
        btn:SetPoint("LEFT", filterBar, "LEFT", xOffset, 0)
        btn:SetText(filter.name)
        btn.filter = filter.filter
        btn.isSpecial = filter.isSpecial
        btn:SetScript("OnClick", function(self)
            if activeFilter == self.filter then
                activeFilter = nil
            else
                activeFilter = self.filter
            end
            Frame:UpdateLayout()
        end
        table.insert(filterButtons, btn)
        xOffset = xOffset + 62
    end
    filterBar.filterButtons = filterButtons
    Frame.filterBar = filterBar
end

local function CreateBagPanel()
    local bagPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    bagPanel:SetHeight(SLOT_SIZE + 8)
    bagPanel:SetPoint("TOPLEFT", Frame.filterBar, "BOTTOMLEFT", 0, -2)
    bagPanel:SetPoint("TOPRIGHT", Frame.filterBar, "BOTTOMRIGHT", 0, -2)
    bagPanel:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    bagPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.6)
    bagPanel:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    bagPanel:Hide()
    bagPanel.slots = {}
    Frame.bagPanel = bagPanel
end

function Frame:UpdateBagPanelVisibility()
    if currentMode == "bags" and OI.db and OI.db.char and OI.db.char.settings and OI.db.char.settings.showBagPanel then
        self.bagPanel:Show()
        self.contentArea:SetPoint("TOPLEFT", self.bagPanel, "BOTTOMLEFT", 0, -2)
        self.contentArea:SetPoint("TOPRIGHT", self.bagPanel, "BOTTOMRIGHT", 0, -2)
    else
        self.bagPanel:Hide()
        self.contentArea:SetPoint("TOPLEFT", self.filterBar, "BOTTOMLEFT", 0, -2)
        self.contentArea:SetPoint("TOPRIGHT", self.filterBar, "BOTTOMRIGHT", 0, -2)
    end
end

function Frame:UpdateBagPanel()
    if not self.bagPanel then return end
    for _, slot in ipairs(self.bagPanel.slots) do
        if OI.BagSlot and OI.BagSlot.Release then
            OI.BagSlot:Release(slot)
        end
    end
    self.bagPanel.slots = {}
    local xOffset = 4
    local numBags = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            numBags = numBags + 1
        end
    end
    local totalWidth = numBags * (SLOT_SIZE + SLOT_SPACING) - SLOT_SPACING + 8
    local bagIndex = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots and numSlots > 0 then
            local slot
            if OI.BagSlot and OI.BagSlot.Create then
                slot = OI.BagSlot:Create(self.bagPanel, bag)
            else
                slot = CreateFrame("Button", nil, self.bagPanel, "BackdropTemplate")
                slot:SetSize(SLOT_SIZE, SLOT_SIZE)
                slot:SetBackdrop({
                    bgFile = "Interface\Buttons\WHITE8X8",
                    edgeFile = "Interface\Buttons\WHITE8X8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                slot:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
                slot:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
                local icon = slot:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints()
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                slot.icon = icon
                local texture = GetContainerItemInfo(bag, 1)
                if texture then
                    slot.icon:SetTexture(texture)
                else
                    slot.icon:SetTexture("Interface\Buttons\WHITE8X8")
                    slot.icon:SetVertexColor(0.3, 0.3, 0.3, 0.5)
                end
            end
            slot:SetPoint("LEFT", self.bagPanel, "LEFT", xOffset, 0)
            slot:SetScript("OnEnter", function(self)
                Frame:SetBagHighlight(bag)
            end)
            slot:SetScript("OnLeave", function(self)
                Frame:SetBagHighlight(nil)
            end)
            table.insert(self.bagPanel.slots, slot)
            xOffset = xOffset + SLOT_SIZE + SLOT_SPACING
            bagIndex = bagIndex + 1
        end
    end
end

function Frame:SetBagHighlight(bagID)
    if not self.contentArea then return end
    for _, btn in pairs(itemButtons) do
        if btn and btn:IsShown() then
            if bagID and btn.bagID ~= bagID then
                btn:SetAlpha(0.3)
            else
                btn:SetAlpha(1)
            end
        end
    end
end

local function CreateContentArea()
    local contentArea = CreateFrame("ScrollFrame", "OmniInventoryContentScroll", mainFrame, "UIPanelScrollFrameTemplate")
    contentArea:SetPoint("TOPLEFT", Frame.filterBar, "BOTTOMLEFT", 0, -2)
    contentArea:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -PADDING - 20, FOOTER_HEIGHT + PADDING + 2)
    contentArea:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    contentArea:SetBackdropColor(0.02, 0.02, 0.02, 0.5)
    contentArea:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
    local scrollChild = CreateFrame("Frame", nil, contentArea)
    scrollChild:SetWidth(contentArea:GetWidth())
    scrollChild:SetHeight(1)
    contentArea:SetScrollChild(scrollChild)
    contentArea.scrollChild = scrollChild
    Frame.contentArea = contentArea
    Frame.scrollChild = scrollChild
end

local function CreateFooter()
    local footer = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    footer:SetHeight(FOOTER_HEIGHT)
    footer:SetPoint("BOTTOMLEFT", PADDING, PADDING)
    footer:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    footer:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    footer:SetBackdropColor(0.05, 0.05, 0.05, 0.8)
    footer:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    local slotCount = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotCount:SetPoint("LEFT", 8, 0)
    slotCount:SetText("0/0")
    footer.slotCount = slotCount
    local sellJunkBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    sellJunkBtn:SetSize(80, FOOTER_HEIGHT - 4)
    sellJunkBtn:SetPoint("RIGHT", -4, 0)
    sellJunkBtn:SetText("Sell Junk")
    sellJunkBtn:SetScript("OnClick", function()
        Frame:SellJunk()
    end)
    footer.sellJunkBtn = sellJunkBtn
    local moneyDisplay = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    moneyDisplay:SetPoint("RIGHT", sellJunkBtn, "LEFT", -8, 0)
    moneyDisplay:SetText("")
    footer.moneyDisplay = moneyDisplay
    moneyDisplay:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine("Character Gold", 1, 1, 1)
        GameTooltip:AddLine(" ")
        local totalGold = 0
        if OI.db and OI.db.realm then
            for realmName, realmData in pairs(OI.db.realm) do
                for charName, charData in pairs(realmData) do
                    if charData.gold and charData.gold > 0 then
                        local color = charData.class and RAID_CLASS_COLORS[charData.class]
                        local nameStr = color and string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, charName) or charName
                        GameTooltip:AddDoubleLine(nameStr, string.format("|cffffd700%dg|r", math.floor(charData.gold / 10000)))
                        totalGold = totalGold + charData.gold
                    end
                end
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("Total", string.format("|cffffd700%dg|r", math.floor(totalGold / 10000)))
        GameTooltip:Show()
    end)
    moneyDisplay:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    Frame.footer = footer
end

local function CreateResizeHandle()
    local resize = CreateFrame("Button", nil, mainFrame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT")
    resize:SetNormalTexture("Interface\Buttons\UI-ScrollBar-ScrollDownButton-Up")
    resize:SetHighlightTexture("Interface\Buttons\UI-Common-MouseHilight", "ADD")
    resize:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            mainFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resize:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            mainFrame:StopMovingOrSizing()
            Frame:SavePosition()
            Frame:UpdateLayout()
        end
    end)
    Frame.resizeHandle = resize
end

function Frame:SavePosition()
    if not OI.db or not OI.db.char then return end
    if not OI.db.char.position then
        OI.db.char.position = {}
    end
    local point, _, relPoint, x, y = mainFrame:GetPoint()
    OI.db.char.position.point = point
    OI.db.char.position.relPoint = relPoint
    OI.db.char.position.x = x
    OI.db.char.position.y = y
    OI.db.char.position.width = mainFrame:GetWidth()
    OI.db.char.position.height = mainFrame:GetHeight()
end

function Frame:LoadPosition()
    if not OI.db or not OI.db.char or not OI.db.char.position then return end
    local pos = OI.db.char.position
    mainFrame:ClearAllPoints()
    if pos.point and pos.relPoint and pos.x and pos.y then
        mainFrame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        mainFrame:SetPoint("CENTER")
    end
    if pos.width and pos.height then
        mainFrame:SetSize(pos.width, pos.height)
    end
end

function Frame:SetScale(scale)
    if mainFrame then
        mainFrame:SetScale(scale or 1)
    end
end

function Frame:ResetPosition()
    mainFrame:ClearAllPoints()
    mainFrame:SetPoint("CENTER")
    mainFrame:SetSize(FRAME_DEFAULT_WIDTH, FRAME_DEFAULT_HEIGHT)
    if OI.db and OI.db.char then
        OI.db.char.position = nil
        if OI.db.char.settings then
            OI.db.char.settings.scale = 1
        end
    end
    mainFrame:SetScale(1)
end

function Frame:ToggleEditMode()
    editMode = not editMode
    if self.header and self.header.editBtn then
        self.header.editBtn:SetText(editMode and "Done" or "Edit")
    end
    self:UpdateLayout()
end

function Frame:IsEditMode()
    return editMode
end

function Frame:ToggleCategoryCollapse(category)
    if collapsedCategories[category] then
        collapsedCategories[category] = nil
    else
        collapsedCategories[category] = true
    end
    self:UpdateLayout()
end

function Frame:IsCategoryCollapsed(category)
    return collapsedCategories[category]
end

function Frame:SetView(view)
    currentView = view
    if self.header and self.header.viewBtn then
        local label = view == "grid" and "Grid" or (view == "flow" and "Flow" or "List")
        if self.header.viewBtn.text then
            self.header.viewBtn.text:SetText(label)
        else
            self.header.viewBtn:SetText(label)
        end
    end
    self:ForceRender()
end

function Frame:CycleView()
    if currentView == "grid" then
        self:SetView("flow")
    elseif currentView == "flow" then
        self:SetView("list")
    else
        self:SetView("grid")
    end
end

function Frame:CycleSort()
    if OI.Sorter and OI.Sorter.CycleSortMode then
        OI.Sorter:CycleSortMode()
    elseif OI.Sorter and OI.Sorter.GetModes then
        local modes = OI.Sorter:GetModes()
        local cur = OI.Sorter:GetDefaultMode()
        for i, mode in ipairs(modes) do
            if mode == cur then
                OI.Sorter:SetDefaultMode(modes[(i % #modes) + 1])
                break
            end
        end
    end
    self:UpdateLayout()
end

function Frame:SetMode(mode)
    if mode ~= "bags" and mode ~= "bank" and mode ~= "keys" then return end
    currentMode = mode
    self:UpdateBankTabState()
    self:UpdateBagPanelVisibility()
    self:UpdateLayout()
end

function Frame:GetMode()
    return currentMode
end

function Frame:UpdateBankTabState()
    if not self.header then return end
    local header = self.header
    if header.bagsTab then
        header.bagsTab:SetTextColor(currentMode == "bags" and 0 or 1, currentMode == "bags" and 1 or 0.8, currentMode == "bags" and 0 or 0.8, 1)
    end
    if header.bankTab then
        if isBankOpen then
            header.bankTab:SetTextColor(currentMode == "bank" and 0 or 1, currentMode == "bank" and 1 or 0.8, currentMode == "bank" and 0 or 0.8, 1)
            header.bankTab:Enable()
        else
            header.bankTab:SetTextColor(0.5, 0.5, 0.5, 1)
            header.bankTab:Disable()
        end
    end
    if header.keysTab then
        header.keysTab:SetTextColor(currentMode == "keys" and 0 or 1, currentMode == "keys" and 1 or 0.8, currentMode == "keys" and 0 or 0.8, 1)
    end
end

function Frame:SetBankOpen(open)
    isBankOpen = open
    self:UpdateBankTabState()
    if currentMode == "bank" and not open then
        self:SetMode("bags")
    end
end

function Frame:IsBankOpen()
    return isBankOpen
end

function Frame:SetViewedCharacter(charName)
    viewedChar = charName or UnitName("player")
    if self.header and self.header.charBtn then
        self.header.charBtn:SetText(viewedChar)
    end
    self:UpdateLayout()
end

function Frame:GetViewedCharacter()
    return viewedChar
end

function Frame:ToggleCharacterDropdown(anchor)
    local menu = {}
    local playerName = UnitName("player")
    table.insert(menu, {
        text = playerName,
        checked = viewedChar == playerName,
        func = function()
            Frame:SetViewedCharacter(playerName)
            CloseDropDownMenus()
        end
    })
    if OI.db and OI.db.realm then
        for realmName, realmData in pairs(OI.db.realm) do
            for charName, _ in pairs(realmData) do
                if charName ~= playerName then
                    table.insert(menu, {
                        text = charName .. " (" .. realmName .. ")",
                        checked = viewedChar == charName,
                        func = function()
                            Frame:SetViewedCharacter(charName)
                            CloseDropDownMenus()
                        end
                    })
                end
            end
        end
    end
    EasyMenu(menu, "cursor", anchor, 0, 0, "MENU")
end

function Frame:UpdateLayout(changedBags)
    local newState = ComputeLayoutState()
    if not NeedsRender(newState) then return end
    lastLayoutState = newState
    local items = {}
    local isLive = (viewedChar == UnitName("player"))
    if isLive then
        if currentMode == "bags" then
            for bag = 0, 4 do
                local numSlots = GetContainerNumSlots(bag)
                for slot = 1, numSlots do
                    local texture, count, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
                    if texture then
                        table.insert(items, {
                            bagID = bag,
                            slotID = slot,
                            texture = texture,
                            count = count or 1,
                            quality = quality,
                            link = itemLink,
                            name = itemLink and (GetItemInfo(itemLink) or "Unknown") or "Unknown",
                            itemID = itemID,
                            filtered = isFiltered
                        })
                    end
                end
            end
        elseif currentMode == "bank" then
            for bag = -1, 11 do
                local numSlots = GetContainerNumSlots(bag)
                if numSlots and numSlots > 0 then
                    for slot = 1, numSlots do
                        local texture, count, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
                        if texture then
                            table.insert(items, {
                                bagID = bag,
                                slotID = slot,
                                texture = texture,
                                count = count or 1,
                                quality = quality,
                                link = itemLink,
                                name = itemLink and (GetItemInfo(itemLink) or "Unknown") or "Unknown",
                                itemID = itemID,
                                filtered = isFiltered
                            })
                        end
                    end
                end
            end
        elseif currentMode == "keys" then
            local numSlots = GetKeyRingSize and GetKeyRingSize() or 0
            for slot = 1, numSlots do
                local texture, count, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(-2, slot)
                if texture then
                    table.insert(items, {
                        bagID = -2,
                        slotID = slot,
                        texture = texture,
                        count = count or 1,
                        quality = quality,
                        link = itemLink,
                        name = itemLink and (GetItemInfo(itemLink) or "Unknown") or "Unknown",
                        itemID = itemID,
                        filtered = isFiltered
                    })
                end
            end
        end
    else
        if OI.Bags and OI.Bags.GetOfflineItems then
            items = OI.Bags:GetOfflineItems(viewedChar, currentMode == "bank") or {}
        end
    end
    if activeFilter then
        local filtered = {}
        for _, item in ipairs(items) do
            local cat = OI.Categorizer and OI.Categorizer:GetCategory(item) or "Other"
            if item.filtered or cat == activeFilter then
                table.insert(filtered, item)
            end
        end
        items = filtered
    end
    if OI.Sorter and OI.Sorter.Sort then
        items = OI.Sorter:Sort(items, OI.Sorter:GetDefaultMode())
    end
    if currentView == "list" then
        self:RenderListView(items)
    else
        self:RenderFlowView(items)
    end
    self:UpdateSlotCount()
    self:UpdateMoney()
    self:UpdateFooterButton()
    self:UpdateSpecialButtons()
end

function Frame:RenderFlowView(items)
    if not self.scrollChild then return end
    for _, btn in pairs(itemButtons) do
        if OI.Pool and OI.Pool.Release then
            OI.Pool:Release("ItemButton", btn)
        else
            btn:Hide()
            btn:ClearAllPoints()
        end
    end
    for _, header in pairs(categoryHeaders) do
        header:Hide()
        header:ClearAllPoints()
    end
    itemButtons = {}
    categoryHeaders = {}
    local contentWidth = self.contentArea:GetWidth() or FRAME_DEFAULT_WIDTH
    local usableWidth = contentWidth - (PADDING * 2)
    local categories = {}
    if currentView == "grid" then
        local categoryItems = {}
        for _, item in ipairs(items) do
            local cat = OI.Categorizer and OI.Categorizer:GetCategory(item) or "Other"
            if not categoryItems[cat] then
                categoryItems[cat] = {}
            end
            table.insert(categoryItems[cat], item)
        end
        for cat, catItems in pairs(categoryItems) do
            table.insert(categories, { name = cat, items = catItems })
        end
        table.sort(categories, function(a, b) return a.name < b.name end)
    else
        local grouped = {}
        for _, item in ipairs(items) do
            local cat = OI.Categorizer and OI.Categorizer:GetCategory(item) or "Other"
            if not grouped[cat] then
                grouped[cat] = {}
            end
            table.insert(grouped[cat], item)
        end
        for cat, catItems in pairs(grouped) do
            table.insert(categories, { name = cat, items = catItems })
        end
        table.sort(categories, function(a, b) return a.name < b.name end)
        if OI.FlowView and OI.FlowView.PackLayout then
            local numCols = math.floor(usableWidth / (ITEM_SIZE + ITEM_SPACING))
            if numCols < 1 then numCols = 1 end
            for _, catData in ipairs(categories) do
                catData.packedItems = OI.FlowView:PackLayout(catData.items, numCols, function(item)
                    return catData.name
                end)
            end
        end
    end
    local yOffset = 0
    for _, catData in ipairs(categories) do
        local isCollapsed = editMode and collapsedCategories[catData.name]
        local headerBtn = CreateFrame("Button", nil, self.scrollChild, "BackdropTemplate")
        headerBtn:SetWidth(usableWidth)
        headerBtn:SetHeight(20)
        headerBtn:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 4, -yOffset)
        headerBtn:SetBackdrop({
            bgFile = "Interface\Buttons\WHITE8X8",
            edgeFile = "Interface\Buttons\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        headerBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
        headerBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        local label = headerBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", 8, 0)
        label:SetText(catData.name .. " (" .. #catData.items .. ")")
        label:SetTextColor(0, 1, 0, 1)
        headerBtn.label = label
        if editMode then
            local collapseBtn = CreateFrame("Button", nil, headerBtn)
            collapseBtn:SetSize(16, 16)
            collapseBtn:SetPoint("RIGHT", -4, 0)
            collapseBtn:SetText(isCollapsed and "+" or "-")
            collapseBtn:SetScript("OnClick", function()
                Frame:ToggleCategoryCollapse(catData.name)
            end)
            headerBtn.collapseBtn = collapseBtn
        end
        headerBtn:Show()
        table.insert(categoryHeaders, headerBtn)
        yOffset = yOffset + 22
        if not isCollapsed then
            local cols = math.floor(usableWidth / (ITEM_SIZE + ITEM_SPACING))
            if cols < 1 then cols = 1 end
            local row = 0
            local col = 0
            for i, item in ipairs(catData.items) do
                local btn
                if OI.Pool and OI.Pool.Acquire then
                    btn = OI.Pool:Acquire("ItemButton")
                end
                if btn then
                    btn:SetParent(self.scrollChild)
                    if OI.ItemButton and OI.ItemButton.SetItem then
                        OI.ItemButton:SetItem(btn, item)
                    end
                else
                    btn = CreateFrame("Button", nil, self.scrollChild, "BackdropTemplate")
                    btn:SetSize(ITEM_SIZE, ITEM_SIZE)
                    btn:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        edgeSize = 1,
                        insets = { left = 1, right = 1, top = 1, bottom = 1 }
                    })
                    btn:SetBackdropColor(0.15, 0.15, 0.15, 0.8)
                    btn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
                    local icon = btn:CreateTexture(nil, "ARTWORK")
                    icon:SetAllPoints()
                    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    btn.icon = icon
                    local countStr = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    countStr:SetPoint("BOTTOMRIGHT", -2, 2)
                    countStr:SetFont("Fonts\\ARIALN.TTF", 10, "OUTLINE")
                    countStr:SetTextColor(1, 1, 1, 1)
                    btn.countStr = countStr
                    local qualityBorder = btn:CreateTexture(nil, "OVERLAY")
                    qualityBorder:SetAllPoints()
                    qualityBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
                    qualityBorder:SetBlendMode("ADD")
                    btn.qualityBorder = qualityBorder
                    btn.bagID = item.bagID
                    btn.slotID = item.slotID
                    btn.itemData = item
                    if btn.icon then btn.icon:SetTexture(item.texture) end
                    if btn.countStr then
                        if item.count and item.count > 1 then btn.countStr:SetText(item.count)
                        else btn.countStr:SetText("") end
                    end
                    if btn.qualityBorder and item.quality then
                        local r, g, b = GetItemQualityColor(item.quality)
                        btn.qualityBorder:SetVertexColor(r, g, b, 0.15)
                    end
                    btn:SetScript("OnEnter", function(self)
                        if self.itemData and self.itemData.link then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink(self.itemData.link)
                            GameTooltip:Show()
                        end
                        if self.bagID then Frame:SetBagHighlight(self.bagID) end
                    end)
                    btn:SetScript("OnLeave", function(self) GameTooltip:Hide(); Frame:SetBagHighlight(nil) end)
                    btn:SetScript("OnClick", function(self, button)
                        if IsShiftKeyDown() then HandleModifiedItemClick(self.itemData and self.itemData.link)
                        elseif IsControlKeyDown() then DressUpItemLink(self.itemData and self.itemData.link)
                        elseif IsAltKeyDown() then
                            if OI.db and OI.db.global and OI.db.global.itemActions then
                                OI.db.global.itemActions[self.itemData.itemID] = true
                            end
                        end
                    end)
                end
                local xOff = (col % cols) * (ITEM_SIZE + ITEM_SPACING) + 4
                local yOff = row * (ITEM_SIZE + ITEM_SPACING)
                btn:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", xOff, -yOffset - yOff)
                btn:Show()
                table.insert(itemButtons, btn)
                col = col + 1
                if col >= cols then col = 0; row = row + 1 end
            end
            local totalRows = row + (col > 0 and 1 or 0)
            yOffset = yOffset + totalRows * (ITEM_SIZE + ITEM_SPACING)
        else
            yOffset = yOffset + 2
        end
        yOffset = yOffset + SECTION_SPACING
    end
    self.scrollChild:SetHeight(math.max(yOffset, 1))
end

function Frame:RenderListView(items)
    if not self.scrollChild then return end
    for _, row in pairs(listRows) do
        row:Hide()
    end
    listRows = {}
    local contentWidth = self.contentArea:GetWidth() or FRAME_DEFAULT_WIDTH
    local usableWidth = contentWidth - (PADDING * 2)
    local yOffset = 0
    local rowHeight = 20
    local headerRow = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
    headerRow:SetWidth(usableWidth)
    headerRow:SetHeight(rowHeight)
    headerRow:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 4, -yOffset)
    headerRow:SetBackdrop({
        bgFile = "Interface\Buttons\WHITE8X8",
        edgeFile = "Interface\Buttons\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    headerRow:SetBackdropColor(0.15, 0.15, 0.15, 1)
    headerRow:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local headerIcon = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerIcon:SetPoint("LEFT", 4, 0)
    headerIcon:SetText("Icon")
    local headerName = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerName:SetPoint("LEFT", headerIcon, "RIGHT", 8, 0)
    headerName:SetText("Name")
    local headerType = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerType:SetPoint("LEFT", headerName, "RIGHT", 120, 0)
    headerType:SetText("Type")
    local headerCount = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerCount:SetPoint("RIGHT", -8, 0)
    headerCount:SetText("Count")
    headerRow:Show()
    table.insert(listRows, headerRow)
    yOffset = yOffset + rowHeight + 2
    for _, item in ipairs(items) do
        local row = CreateFrame("Frame", nil, self.scrollChild, "BackdropTemplate")
        row:SetWidth(usableWidth)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 4, -yOffset)
        row:SetBackdrop({
            bgFile = "Interface\Buttons\WHITE8X8",
            edgeFile = "Interface\Buttons\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 }
        })
        row:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
        row:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(rowHeight - 4, rowHeight - 4)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(item.texture)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local nameStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameStr:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        nameStr:SetText(item.name or "Unknown")
        local typeStr = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        typeStr:SetPoint("LEFT", nameStr, "RIGHT", 120, 0)
        typeStr:SetText(OI.Categorizer and OI.Categorizer:GetCategory(item) or "")
        local countStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countStr:SetPoint("RIGHT", -8, 0)
        countStr:SetText(item.count and item.count > 1 and item.count or "")
        if item.quality then
            local r, g, b = GetItemQualityColor(item.quality)
            nameStr:SetTextColor(r, g, b, 1)
        end
        row:SetScript("OnEnter", function(self)
            if item.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(item.link)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        row:SetScript("OnMouseUp", function(self, button)
            if IsShiftKeyDown() then
                HandleModifiedItemClick(item.link)
            elseif IsControlKeyDown() then
                DressUpItemLink(item.link)
            end
        end)
        row:Show()
        table.insert(listRows, row)
        yOffset = yOffset + rowHeight + 1
    end
    self.scrollChild:SetHeight(math.max(yOffset, 1))
end

function Frame:ApplySearch(text)
    if not text or text == "" then
        for _, btn in pairs(itemButtons) do
            if btn then
                btn:SetAlpha(1)
            end
        end
        for _, row in pairs(listRows) do
            if row then
                row:SetAlpha(1)
            end
        end
        return
    end
    local lowerText = strlower(text)
    for _, btn in pairs(itemButtons) do
        if btn and btn.itemData then
            local name = btn.itemData.name or ""
            if strfind(strlower(name), lowerText, 1, true) then
                btn:SetAlpha(1)
            else
                btn:SetAlpha(0.3)
            end
        end
    end
    for _, row in pairs(listRows) do
        if row then
            local nameStr = row.nameStr
            if nameStr then
                local name = nameStr:GetText() or ""
                if strfind(strlower(name), lowerText, 1, true) then
                    row:SetAlpha(1)
                else
                    row:SetAlpha(0.3)
                end
            end
        end
    end
end

function Frame:UpdateSlotCount()
    if not self.footer then return end
    local used = 0
    local total = 0
    if currentMode == "bags" then
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            total = total + numSlots
            for slot = 1, numSlots do
                local texture = GetContainerItemInfo(bag, slot)
                if texture then
                    used = used + 1
                end
            end
        end
    elseif currentMode == "bank" then
        for bag = -1, 11 do
            local numSlots = GetContainerNumSlots(bag)
            if numSlots and numSlots > 0 then
                total = total + numSlots
                for slot = 1, numSlots do
                    local texture = GetContainerItemInfo(bag, slot)
                    if texture then
                        used = used + 1
                    end
                end
            end
        end
    elseif currentMode == "keys" then
        total = GetKeyRingSize and GetKeyRingSize() or 0
        for slot = 1, total do
            local texture = GetContainerItemInfo(-2, slot)
            if texture then
                used = used + 1
            end
        end
    end
    self.footer.slotCount:SetText(used .. "/" .. total)
end

function Frame:UpdateMoney()
    if not self.footer then return end
    local money = GetMoney("player") or 0
    local gold = math.floor(money / 10000)
    local silver = math.floor((money % 10000) / 100)
    local copper = money % 100
    local text = ""
    if gold > 0 then
        text = gold .. "|cFFFFD700g|r "
    end
    if silver > 0 then
        text = text .. silver .. "|cFFC0C0C0s|r "
    end
    text = text .. copper .. "|cFFB87333c|r"
    self.footer.moneyDisplay:SetText(text)
end

function Frame:UpdateFooterButton()
    if not self.footer then return end
    if isMerchantOpen then
        self.footer.sellJunkBtn:Show()
    else
        self.footer.sellJunkBtn:Hide()
    end
end

function Frame:SellJunk()
    if not isMerchantOpen then return end
    local soldCount = 0
    for bag = 0, 4 do
        local numSlots = GetContainerNumSlots(bag)
        for slot = numSlots, 1, -1 do
            local texture, count, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
            if texture and quality == 0 and not locked then
                UseContainerItem(bag, slot)
                soldCount = soldCount + 1
            end
        end
    end
    if soldCount > 0 then
        print("|cFF00FF00OmniInventory|r: Sold " .. soldCount .. " junk items.")
    end
end

function Frame:UpdateSpecialButtons()
    if not self.header then return end
    local hearthBtn = self.header.hearthBtn
    if hearthBtn then
        local hasHearthstone = false
        local hearthSpellID = nil
        for bag = 0, 4 do
            local numSlots = GetContainerNumSlots(bag)
            for slot = 1, numSlots do
                local texture, count, locked, quality, readable, lootable, itemLink, isFiltered, noValue, itemID = GetContainerItemInfo(bag, slot)
                if itemID == 6948 or itemID == 110560 or itemID == 140192 or itemID == 129276 then
                    hasHearthstone = true
                    hearthSpellID = itemID == 6948 and 8690 or (itemID == 110560 and 18960 or (itemID == 140192 and 226234 or 226234))
                    break
                end
            end
            if hasHearthstone then break end
        end
        if hasHearthstone then
            hearthBtn:Show()
            hearthBtn:SetAttribute("type", "spell")
            hearthBtn:SetAttribute("spell", GetSpellInfo(hearthSpellID))
        else
            hearthBtn:Hide()
        end
    end
end

function Frame:PhysicalSortBags()
    if OI.Sorter and OI.Sorter.PhysicalSort then
        OI.Sorter:PhysicalSort(currentMode == "bank")
    end
    self:ForceRender()
end

function Frame:Show()
    if not mainFrame then
        CreateMainFrame()
    end
    mainFrame:Show()
end

function Frame:Hide()
    if mainFrame then
        mainFrame:Hide()
    end
end

function Frame:Toggle()
    if mainFrame and mainFrame:IsShown() then
        Frame:Hide()
    else
        Frame:Show()
    end
end

function Frame:IsShown()
    return mainFrame and mainFrame:IsShown()
end

function Frame:Init()
    self:RegisterEvents()
end

function Frame:RegisterEvents()
    OI:RegisterBucketEvent("BAG_UPDATE", 0.5, function(changedBags)
        Frame:UpdateLayout(changedBags)
        -- Notify tooltip cache to refresh after bag changes
        if OI.SendMessage then
            OI:SendMessage("TooltipUpdated")
        end
    end)
    OI:RegisterEvent("MERCHANT_SHOW", function()
        isMerchantOpen = true
        Frame:UpdateFooterButton()
    end)
    OI:RegisterEvent("MERCHANT_CLOSED", function()
        isMerchantOpen = false
        Frame:UpdateFooterButton()
    end)
end

print("|cFF00FF00OmniInventory|r: Container loaded")
