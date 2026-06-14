local addonName, OI = ...
OI.FlowView = {}
local FlowView = OI.FlowView

local ITEM_SIZE = 37
local ITEM_SPACING = 4
local SECTION_SPACING = 8
local SECTION_HEADER_HEIGHT = 18
local COLUMN_WIDTH = ITEM_SIZE + ITEM_SPACING
local COLUMN_HEIGHT = ITEM_SIZE + ITEM_SPACING

local currentLayout = nil

function FlowView:GetLayout()
    return currentLayout
end

function FlowView:PackLayout(items, numColumns, categorizerFunc)
    if not items or #items == 0 then
        currentLayout = { sections = {}, totalHeight = 0, totalWidth = 0 }
        return currentLayout
    end

    numColumns = numColumns or 10
    local sections = {}
    local categorized = {}
    local catOrder = {}

    for _, item in ipairs(items) do
        local cat = categorizerFunc and categorizerFunc(item) or "Miscellaneous"
        if not categorized[cat] then
            categorized[cat] = {}
            table.insert(catOrder, cat)
        end
        table.insert(categorized[cat], item)
    end

    for _, catName in ipairs(catOrder) do
        local catItems = categorized[catName]
        if catItems and #catItems > 0 then
            local catInfo = OI.Categorizer and OI.Categorizer:GetCategoryInfo(catName)
            local numItems = #catItems
            local numItemCols = math.ceil(numItems / 1)
            local effectiveCols = math.min(numColumns, numItems)
            local numRows = math.ceil(numItems / effectiveCols)

            local sectionWidth = effectiveCols * COLUMN_WIDTH
            local sectionHeight = SECTION_HEADER_HEIGHT + numRows * COLUMN_HEIGHT

            table.insert(sections, {
                name = catName,
                items = catItems,
                color = catInfo and catInfo.color or { r = 0.5, g = 0.5, b = 0.5 },
                height = sectionHeight,
                width = sectionWidth,
                numColumns = effectiveCols,
                numRows = numRows,
                numItems = numItems,
            })
        end
    end

    local totalWidth = numColumns * COLUMN_WIDTH
    local totalHeight = 0
    for _, sec in ipairs(sections) do
        totalHeight = totalHeight + sec.height + SECTION_SPACING
    end
    totalHeight = totalHeight - SECTION_SPACING

    if totalHeight < COLUMN_HEIGHT then totalHeight = COLUMN_HEIGHT end

    currentLayout = {
        sections = sections,
        totalHeight = totalHeight,
        totalWidth = totalWidth,
        numColumns = numColumns,
    }

    return currentLayout
end

function FlowView:ArrangeItems(sections, scrollChild, buttonPool, numColumns)
    if not sections or not scrollChild or not buttonPool then return end
    numColumns = numColumns or 10

    local xOffset = 0
    local yOffset = 0

    for _, section in ipairs(sections) do
        local header = buttonPool:Acquire()
        if header then
            header:SetParent(scrollChild)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", xOffset, -yOffset)
            header:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yOffset)
            header:SetHeight(SECTION_HEADER_HEIGHT)
            header:Show()
            table.insert(currentLayout._activeHeaders or {}, header)
        end
        yOffset = yOffset + SECTION_HEADER_HEIGHT

        for i, item in ipairs(section.items) do
            local col = ((i - 1) % numColumns)
            local row = math.floor((i - 1) / numColumns)
            local ix = xOffset + col * COLUMN_WIDTH
            local iy = yOffset + row * COLUMN_HEIGHT

            local btn = buttonPool:Acquire()
            if btn then
                btn:SetParent(scrollChild)
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", ix, -iy)
                btn:SetSize(ITEM_SIZE, ITEM_SIZE)
                btn:Show()
                if OI.ItemButton and OI.ItemButton.SetItem then
                    OI.ItemButton:SetItem(btn, item)
                end
                table.insert(currentLayout._activeButtons or {}, btn)
            end
        end

        yOffset = yOffset + section.numRows * COLUMN_HEIGHT + SECTION_SPACING
    end
end

function FlowView:Reset()
    if currentLayout and currentLayout._activeHeaders then
        for _, h in ipairs(currentLayout._activeHeaders) do
            h:ClearAllPoints()
            h:Hide()
            h:SetParent(UIParent)
        end
    end
    if currentLayout and currentLayout._activeButtons then
        for _, b in ipairs(currentLayout._activeButtons) do
            if OI.ItemButton and OI.ItemButton.Reset then
                OI.ItemButton:Reset(b)
            end
            b:ClearAllPoints()
            b:Hide()
            b:SetParent(UIParent)
        end
    end
    currentLayout = { sections = {}, totalHeight = 0, totalWidth = 0, _activeHeaders = {}, _activeButtons = {} }
end

function FlowView:GetSectionAtPoint(y, sections)
    if not sections then return nil end
    local offset = 0
    for _, sec in ipairs(sections) do
        if y >= offset and y < offset + sec.height then return sec end
        offset = offset + sec.height + SECTION_SPACING
    end
    return nil
end

print("|cFF00FF00OmniInventory|r: FlowView loaded")
