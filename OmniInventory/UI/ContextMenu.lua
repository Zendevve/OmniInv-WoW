-- =============================================================================
-- OmniInventory Item Context Menu
-- =============================================================================
-- Right-click context menu for item buttons.
-- =============================================================================

local addonName, Omni = ...

Omni.ContextMenu = {}
local ContextMenu = Omni.ContextMenu

-- =============================================================================
-- Constants
-- =============================================================================

local MENU_WIDTH = 180
local ROW_HEIGHT = 22
local MENU_BG_COLOR = { 0.1, 0.1, 0.1, 0.95 }
local MENU_BORDER_COLOR = { 0.3, 0.3, 0.3, 1 }
local ROW_HOVER_COLOR = { 0.25, 0.25, 0.25, 1 }
local ROW_NORMAL_COLOR = { 0.15, 0.15, 0.15, 1 }
local TEXT_ENABLED_COLOR = { 1, 1, 1 }
local TEXT_DISABLED_COLOR = { 0.5, 0.5, 0.5 }

-- =============================================================================
-- Menu State
-- =============================================================================

local menuFrame = nil
local menuRows = {}
local currentItemInfo = nil
local currentBagID = nil
local currentSlotID = nil

-- =============================================================================
-- Menu Creation
-- =============================================================================

local function CreateMenuFrame()
    local frame = CreateFrame("Frame", "OmniContextMenu", UIParent)
    frame:SetFrameStrata("DIALOG")
    frame:SetWidth(MENU_WIDTH)
    frame:SetHeight(1)
    frame:EnableMouse(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, tileSize = 1, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    frame:SetBackdropColor(unpack(MENU_BG_COLOR))
    frame:SetBackdropBorderColor(unpack(MENU_BORDER_COLOR))
    frame:Hide()

    frame:SetScript("OnHide", function()
        ContextMenu:Hide()
    end)

    return frame
end

local function GetOrCreateRow(index)
    if menuRows[index] then
        return menuRows[index]
    end

    local row = CreateFrame("Button", nil, menuFrame)
    row:SetHeight(ROW_HEIGHT)
    row:SetWidth(MENU_WIDTH - 2)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.bg:SetVertexColor(unpack(ROW_NORMAL_COLOR))

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", 8, 0)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self)
        if self.isEnabled then
            self.bg:SetVertexColor(unpack(ROW_HOVER_COLOR))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.isEnabled then
            self.bg:SetVertexColor(unpack(ROW_NORMAL_COLOR))
        end
    end)

    menuRows[index] = row
    return row
end

-- =============================================================================
-- Action Definitions
-- =============================================================================

local Actions = {}

function Actions.UseItem()
    if currentBagID and currentSlotID then
        UseContainerItem(currentBagID, currentSlotID)
    end
end

function Actions.TogglePin()
    if currentItemInfo and currentItemInfo.itemID and Omni.Data then
        local isPinned = Omni.Data:TogglePin(currentItemInfo.itemID)
        print(string.format("|cFF00FF00Omni|r: Item %s!", isPinned and "pinned" or "unpinned"))
        if Omni.Frame then
            Omni.Frame:UpdateLayout()
        end
    end
end

function Actions.SearchSimilar()
    if currentItemInfo and Omni.Frame then
        local searchText = ""
        if currentItemInfo.hyperlink then
            local name = GetItemInfo(currentItemInfo.hyperlink)
            searchText = name or ""
        end
        if searchText ~= "" then
            Omni.Frame:SetSearchText(searchText)
        end
    end
end

function Actions.AddToCategory()
    if currentItemInfo and Omni.CategoryEditor then
        Omni.CategoryEditor:OpenForItem(currentItemInfo)
    else
        print("|cFF00FF00Omni|r: Category Editor not available.")
    end
end

function Actions.SendToAlt()
    if not SendMailFrame or not SendMailFrame:IsShown() then
        print("|cFF00FF00Omni|r: Open a mailbox to send items.")
        return
    end
    if currentItemInfo and currentBagID and currentSlotID then
        PickupContainerItem(currentBagID, currentSlotID)
        ClickSendMailItemButton()
    end
end

function Actions.Disenchant()
    if currentItemInfo and currentBagID and currentSlotID then
        local quality = currentItemInfo.quality or 0
        if quality >= 2 then
            CastSpellByName("Disenchant")
            SpellTargetItem(currentBagID, currentSlotID)
        else
            print("|cFF00FF00Omni|r: Item cannot be disenchanted.")
        end
    end
end

-- =============================================================================
-- Menu Builder
-- =============================================================================

local function BuildMenuEntries(itemInfo, bagID, slotID)
    local entries = {}
    local canUse = bagID and slotID and bagID >= 0 and slotID > 0

    table.insert(entries, { text = "Use", action = Actions.UseItem, enabled = canUse })
    table.insert(entries, { text = "Pin / Unpin", action = Actions.TogglePin, enabled = itemInfo and itemInfo.itemID ~= nil })
    table.insert(entries, { text = "Search Similar", action = Actions.SearchSimilar, enabled = itemInfo and itemInfo.hyperlink ~= nil })
    table.insert(entries, { text = "Add to Category", action = Actions.AddToCategory, enabled = itemInfo and itemInfo.itemID ~= nil })
    table.insert(entries, { text = "Send to Alt", action = Actions.SendToAlt, enabled = canUse })

    -- Disenchant only for green+ quality items
    local quality = itemInfo and itemInfo.quality or 0
    local isDisenchantable = quality >= 2
    table.insert(entries, { text = "Disenchant", action = Actions.Disenchant, enabled = isDisenchantable })

    return entries
end

-- =============================================================================
-- Public API
-- =============================================================================

function ContextMenu:Show(itemInfo, bagID, slotID, anchorFrame)
    if not menuFrame then
        menuFrame = CreateMenuFrame()
    end

    currentItemInfo = itemInfo
    currentBagID = bagID
    currentSlotID = slotID

    local entries = BuildMenuEntries(itemInfo, bagID, slotID)

    -- Position menu near cursor or anchor frame
    local x, y
    if anchorFrame then
        x, y = anchorFrame:GetCenter()
    else
        x, y = GetCursorPosition()
        x = x / UIParent:GetEffectiveScale()
        y = y / UIParent:GetEffectiveScale()
    end

    -- Build rows
    for i, entry in ipairs(entries) do
        local row = GetOrCreateRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 1, -((i - 1) * ROW_HEIGHT) - 1)
        row:Show()

        row.text:SetText(entry.text)
        row.isEnabled = entry.enabled

        if entry.enabled then
            row.text:SetTextColor(unpack(TEXT_ENABLED_COLOR))
            row:SetScript("OnClick", function()
                entry.action()
                ContextMenu:Hide()
            end)
        else
            row.text:SetTextColor(unpack(TEXT_DISABLED_COLOR))
            row:SetScript("OnClick", nil)
        end
    end

    -- Hide unused rows
    for i = #entries + 1, #menuRows do
        menuRows[i]:Hide()
    end

    -- Size frame
    menuFrame:SetHeight((#entries * ROW_HEIGHT) + 2)
    menuFrame:SetWidth(MENU_WIDTH)

    -- Position and clamp to screen
    menuFrame:ClearAllPoints()
    menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x - 10, y + 10)

    menuFrame:Show()
end

function ContextMenu:Hide()
    if menuFrame then
        menuFrame:Hide()
    end
    currentItemInfo = nil
    currentBagID = nil
    currentSlotID = nil
end

function ContextMenu:IsShown()
    return menuFrame and menuFrame:IsShown()
end

-- =============================================================================
-- Close on outside click / Escape
-- =============================================================================

-- Register menu for Escape key closing
tinsert(UISpecialFrames, "OmniContextMenu")

-- Click handler that closes menu when clicking outside
local clickHandler = CreateFrame("Frame", nil, UIParent)
clickHandler:SetFrameStrata("TOOLTIP")
clickHandler:SetAllPoints(UIParent)
clickHandler:EnableMouse(true)
clickHandler:Hide()

clickHandler:SetScript("OnMouseDown", function(self, button)
    if not ContextMenu:IsShown() then
        self:Hide()
        return
    end
    -- Check if click is inside the menu
    local mx, my = GetCursorPosition()
    mx = mx / UIParent:GetEffectiveScale()
    my = my / UIParent:GetEffectiveScale()
    local left = menuFrame:GetLeft()
    local right = menuFrame:GetRight()
    local top = menuFrame:GetTop()
    local bottom = menuFrame:GetBottom()
    if left and right and top and bottom then
        if mx >= left and mx <= right and my >= bottom and my <= top then
            -- Click inside menu, don't close
            return
        end
    end
    ContextMenu:Hide()
end)

local oldMenuShow = ContextMenu.Show
ContextMenu.Show = function(self, ...)
    oldMenuShow(self, ...)
    clickHandler:Show()
end

local oldMenuHide = ContextMenu.Hide
ContextMenu.Hide = function(self)
    oldMenuHide(self)
    clickHandler:Hide()
end

print("|cFF00FF00OmniInventory|r: Context Menu loaded")
