local addonName, NS = ...

NS.Inventory = {}
local Inventory = NS.Inventory

-- Bag IDs for WotLK
local BAGS = {0, 1, 2, 3, 4}
local KEYRING = -2
local BANK = {-1, 5, 6, 7, 8, 9, 10, 11}

-- Storage for scanned items
Inventory.items = {}
Inventory.itemCounts = {} -- itemID -> count
Inventory.previousItemCounts = {}

-- Event bucketing to reduce spam
Inventory.updatePending = false
Inventory.bucketDelay = 0.1  -- 100ms delay for coalescing events

-- Dirty flag system for incremental updates
Inventory.dirtySlots = {}
Inventory.previousState = {}  -- bagID:slotID -> {link, count, texture}
Inventory.forceFullUpdate = false

function Inventory:Init()
    -- Initialize SavedVariables structure
    ZenBagsDB = ZenBagsDB or {}

    -- Database Versioning
    local DB_VERSION = 5  -- NEW: Slot-based tracking
    if not ZenBagsDB.version or ZenBagsDB.version < DB_VERSION then
        print("ZenBags: Upgrading database to version " .. DB_VERSION .. ". Resetting data.")
        wipe(ZenBagsDB)
        ZenBagsDB.version = DB_VERSION
    end

    -- NEW SYSTEM: Slot-based tracking (in-memory only, never persisted)
    -- [bagID][slotID] = timestamp
    self.newSlots = {}
    for bag = 0, 4 do
        self.newSlots[bag] = {}
    end

    print("ZenBags: New slot-based tracking initialized")

    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("PLAYER_MONEY")
    self.frame:RegisterEvent("BANKFRAME_OPENED")
    self.frame:RegisterEvent("BANKFRAME_CLOSED")
    self.frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
    self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.frame:RegisterEvent("MERCHANT_SHOW")
    self.frame:RegisterEvent("MERCHANT_CLOSED")

    self.frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "PLAYER_LOGIN" then
            -- Clear all new item highlights on fresh login
            wipe(Inventory.newSlots)
            for bag = 0, 4 do Inventory.newSlots[bag] = {} end
        elseif event == "PLAYER_ENTERING_WORLD" then
            Inventory:ScanBags()
            if NS.Frames then NS.Frames:Update(true) end
        elseif event == "BAG_UPDATE" then
            -- Mark slots as dirty/new
            Inventory:MarkSlotDirty(arg1)
        elseif event == "PLAYERBANKSLOTS_CHANGED" then
             -- Bank updates
             if NS.Data:IsBankOpen() then
                 Inventory:ScanBags()
                 if NS.Frames then NS.Frames:Update(true) end
             end
        elseif event == "PLAYER_MONEY" then
            if NS.Frames and NS.Frames.mainFrame and NS.Frames.mainFrame:IsShown() then
                NS.Frames:UpdateMoney()
            end
        elseif event == "BANKFRAME_OPENED" then
            NS.Data:SetBankOpen(true)
            Inventory:ScanBags()
            if NS.Frames then
                NS.Frames:ShowBankTab()
                NS.Frames:Update(true)
            end
        elseif event == "BANKFRAME_CLOSED" then
            NS.Data:SetBankOpen(false)
            if NS.Frames then
                NS.Frames:Update(true)
            end
        elseif event == "MERCHANT_SHOW" then
            NS.Data:SetMerchantOpen(true)
            if NS.Frames then NS.Frames:Update(true) end
        elseif event == "MERCHANT_CLOSED" then
            NS.Data:SetMerchantOpen(false)
            if NS.Frames then NS.Frames:Update(true) end
        end
    end)
end

function Inventory:MarkSlotDirty(bagID)
    if not bagID or bagID < 0 or bagID > 4 then return end

    self.dirtySlots = self.dirtySlots or {}
    self.dirtySlots[bagID] = true

    -- NEW: Mark new slots when BAG_UPDATE fires
    local numSlots = GetContainerNumSlots(bagID)
    if numSlots then
        for slotID = 1, numSlots do
            local itemID = GetContainerItemID(bagID, slotID)

            if itemID then
               -- Slot has item - mark as new if not already marked
                if not self.newSlots[bagID][slotID] then
                    self.newSlots[bagID][slotID] = time()
                end
            else
                -- Slot is empty - clear any mark
                self.newSlots[bagID][slotID] = nil
            end
        end
    end

    -- Debounce updates
    if not self.updatePending then
        self.updatePending = true
        -- Use OnUpdate for WotLK compatibility
        if not self.timerFrame then
            self.timerFrame = CreateFrame("Frame")
            self.timerFrame:Hide()
            self.timerFrame:SetScript("OnUpdate", function(f, elapsed)
                f.elapsed = (f.elapsed or 0) + elapsed
                if f.elapsed >= Inventory.bucketDelay then
                    f:Hide()
                    f.elapsed = 0
                    Inventory:ScanBags()
                    if NS.Frames then NS.Frames:Update() end
                    Inventory.updatePending = false
                end
            end)
        end
        self.timerFrame:Show()
    end
end

--- Fast path for updating item slot colors without full layout recalculation.
--- Use this for search highlighting, category color changes, etc.
--- Much faster than full Update() cycle.
function Inventory:UpdateItemSlotColors()
    if not NS.Frames or not NS.Frames.buttons then return end

    for _, button in ipairs(NS.Frames.buttons) do
        if button and button:IsVisible() and button.itemData then
            -- Update quality border color
            if button.itemData.quality and button.itemData.quality > 1 then
                local r, g, b = GetItemQualityColor(button.itemData.quality)
                button.IconBorder:SetVertexColor(r, g, b, 1)
                button.IconBorder:Show()
            else
                button.IconBorder:Hide()
            end

            -- Update new item glow
            if NS.Inventory:IsNew(button.itemData.bagID, button.itemData.slotID) then
                button.NewItemTexture:Show()
            else
                button.NewItemTexture:Hide()
            end
        end
    end
end

function Inventory:ScanBags()
    wipe(self.items)

    -- Auto-expire old new slots (5 minutes)
    local currentTime = time()
    for bag = 0, 4 do
        for slot, timestamp in pairs(self.newSlots[bag]) do
            if currentTime - timestamp > 300 then
                self.newSlots[bag][slot] = nil
            end
        end
    end

    -- Scan all bags
    local function scanList(bagList, locationType)
        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            if numSlots then
                for slotID = 1, numSlots do
                    local texture, count, _, quality, _, _, link = GetContainerItemInfo(bagID, slotID)
                    local itemID = GetContainerItemID(bagID, slotID)

                    if link and itemID then
                        local _, _, _, iLevel, _, _, _, _, equipSlot = GetItemInfo(link)
                        local isEquipment = (equipSlot and equipSlot ~= "") and (iLevel and iLevel > 1)

                        -- Check if slot is marked as new
                        local isNew = self.newSlots[bagID] and self.newSlots[bagID][slotID] ~= nil

                        table.insert(self.items, {
                            bagID = bagID,
                            slotID = slotID,
                            link = link,
                            texture = texture,
                            count = count,
                            quality = quality,
                            itemID = itemID,
                            iLevel = isEquipment and iLevel or nil,
                            location = locationType,
                            category = NS.Categories:GetCategory(link, isNew)
                        })
                    end
                end
            end
        end
    end

    scanList(BAGS, "bags")

    if NS.Data:IsBankOpen() then
        scanList(BANK, "bank")
    end

    -- Sort
    table.sort(self.items, function(a, b) return NS.Categories:CompareItems(a, b) end)

    -- Update the Data Layer cache
    NS.Data:UpdateCache()

    -- Mark dirty (simplified for now, full update usually needed after scan)
    self:SetFullUpdate(true)
end

function Inventory:GetItems()
    return self.items
end

function Inventory:MarkDirty(bagID, slotID)
    local key = bagID .. ":" .. (slotID or "all")
    self.dirtySlots[key] = true
end

function Inventory:GetDirtySlots()
    return self.dirtySlots
end

function Inventory:ClearDirtySlots()
    wipe(self.dirtySlots)
end

function Inventory:NeedsFullUpdate()
    return self.forceFullUpdate
end

function Inventory:SetFullUpdate(value)
    self.forceFullUpdate = value
end

-- =============================================================================
-- New Item Tracking
-- =============================================================================

function Inventory:IsNew(bagID, slotID)
    if not bagID or not slotID then return false end
    if bagID < 0 or bagID > 4 then return false end -- Only track main bags
    return self.newSlots[bagID] and self.newSlots[bagID][slotID] ~= nil
end

function Inventory:ClearNew(bagID, slotID)
    if not bagID or not slotID then return end
    if bagID < 0 or bagID > 4 then return end

    if self.newSlots[bagID] then
        self.newSlots[bagID][slotID] = nil
    end

    -- Force update to remove glow
    if NS.Frames then NS.Frames:Update(true) end
end

function Inventory:ClearRecentItems()
    for bag = 0, 4 do
        wipe(self.newSlots[bag])
    end
    -- Force full update to re-categorize items
    self:ScanBags()
    if NS.Frames then NS.Frames:Update(true) end
end

function Inventory:GetTrashItems()
    local trashItems = {}
    for _, item in ipairs(self.items) do
        if item.location == "bags" then
            -- Get item info for quality and category checks
            local _, _, quality, _, _, itemClass, itemSubClass = GetItemInfo(item.link)
            local itemID = select(1, GetItemInfo(item.link))

            -- Exclude Hearthstone (6948) - it's grey but should never be sold
            if itemID == 6948 then
                -- Skip Hearthstone
            -- Check if item is trash:
            -- 1. Grey/Poor quality (quality == 0)
            -- 2. OR marked as Junk category/class by Blizzard (even if common quality)
            elseif quality == 0 or itemClass == "Junk" or itemSubClass == "Junk" then
                table.insert(trashItems, item)
            end
        end
    end
    return trashItems
end

function Inventory:GetTrashValue()
    local totalValue = 0
    for _, item in ipairs(self:GetTrashItems()) do
        local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(item.link)
        if vendorPrice and vendorPrice > 0 then
            totalValue = totalValue + (vendorPrice * item.count)
        end
    end
    return totalValue
end
