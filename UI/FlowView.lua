-- =============================================================================
-- OmniInventory Flow View Layout Engine
-- =============================================================================
-- Purpose: Category-sectioned view (AdiBags-style).
-- Items grouped by category with headers packed in multiple columns.
-- =============================================================================

local addonName, Omni = ...

Omni.FlowView = {}
local FlowView = Omni.FlowView

-- =============================================================================
-- Constants
-- =============================================================================

local ITEM_SIZE = 37
local ITEM_SPACING = 4
local HEADER_HEIGHT = 20
local SECTION_SPACING = 8

-- =============================================================================
-- Layout Calculation & Packing (AdiBags-style)
-- =============================================================================

function FlowView:PackLayout(categorizedItems, categoryOrder, maxColumns, maxHeight)
    local columns = {}
    local currentColumn = { sections = {}, width = 0, height = 0 }
    table.insert(columns, currentColumn)

    -- 1. Calculate dimensions for each section
    local sectionsData = {}
    for _, catName in ipairs(categoryOrder) do
        local items = categorizedItems[catName]
        if items and #items > 0 then
            local secCols = math.min(#items, maxColumns)
            local secRows = math.ceil(#items / secCols)
            local secWidth = secCols * (ITEM_SIZE + ITEM_SPACING) - ITEM_SPACING
            local secHeight = HEADER_HEIGHT + secRows * (ITEM_SIZE + ITEM_SPACING)

            table.insert(sectionsData, {
                name = catName,
                items = items,
                cols = secCols,
                rows = secRows,
                width = secWidth,
                height = secHeight,
            })
        end
    end

    -- 2. Pack sections into columns (greedy column-packing)
    for _, sec in ipairs(sectionsData) do
        local spacing = #currentColumn.sections > 0 and SECTION_SPACING or 0
        local expectedHeight = currentColumn.height + spacing + sec.height

        -- If it fits, or if the current column is empty (must put at least one section)
        if expectedHeight <= maxHeight or #currentColumn.sections == 0 then
            currentColumn.height = currentColumn.height + spacing + sec.height
            currentColumn.width = math.max(currentColumn.width, sec.width)
            table.insert(currentColumn.sections, sec)
        else
            -- Start a new column
            currentColumn = { sections = { sec }, width = sec.width, height = sec.height }
            table.insert(columns, currentColumn)
        end
    end

    -- 3. Compute coordinates relative to scrollChild
    local totalWidth = 0
    local totalHeight = 0
    local currentX = ITEM_SPACING

    for _, col in ipairs(columns) do
        local currentY = -ITEM_SPACING
        for _, sec in ipairs(col.sections) do
            sec.x = currentX
            sec.y = currentY

            sec.itemPositions = {}
            local startItemY = currentY - HEADER_HEIGHT
            for i = 1, #sec.items do
                local c = (i - 1) % sec.cols
                local r = math.floor((i - 1) / sec.cols)
                local ix = currentX + c * (ITEM_SIZE + ITEM_SPACING)
                local iy = startItemY - r * (ITEM_SIZE + ITEM_SPACING)
                table.insert(sec.itemPositions, { x = ix, y = iy })
            end

            -- Update vertical offset for the next section in this column
            currentY = currentY - sec.height - SECTION_SPACING
        end

        -- Content height is determined by the tallest column
        totalHeight = math.max(totalHeight, math.abs(currentY) + ITEM_SPACING)
        currentX = currentX + col.width + SECTION_SPACING
    end

    -- Content width is determined by the total width of all columns
    totalWidth = currentX - SECTION_SPACING + ITEM_SPACING

    return sectionsData, totalWidth, totalHeight
end

function FlowView:GetCategoryOrder(categorizedItems)
    local order = {}

    for catName, _ in pairs(categorizedItems) do
        table.insert(order, catName)
    end

    -- Sort by category priority
    if Omni.Categorizer then
        table.sort(order, function(a, b)
            local infoA = Omni.Categorizer:GetCategoryInfo(a)
            local infoB = Omni.Categorizer:GetCategoryInfo(b)
            return (infoA.priority or 99) < (infoB.priority or 99)
        end)
    else
        table.sort(order)
    end

    return order
end

print("|cFF00FF00OmniInventory|r: FlowView layout engine loaded")
