local addonName, NS = ...

NS.Inventory = {}
local Inventory = NS.Inventory

-- Bag IDs for WotLK
local BAGS = {0, 1, 2, 3, 4}
local KEYRING = -2
local BANK = {-1, 5, 6, 7, 8, 9, 10, 11}

-- Storage for scanned items
Inventory.items = {}

-- Event bucketing to reduce spam
Inventory.updatePending = false
Inventory.bucketDelay = 0.1  -- 100ms delay for coalescing events

-- Dirty flag system for incremental updates
Inventory.dirtySlots = {}
Inventory.previousState = {}  -- bagID:slotID -> {link, count, texture}
Inventory.forceFullUpdate = false

function Inventory:Init()
    self.frame = CreateFrame("Frame")
    self.frame:RegisterEvent("BAG_UPDATE")
    self.frame:RegisterEvent("PLAYER_MONEY")
    self.frame:SetScript("OnEvent", function(self, event, arg1)
        if event == "BAG_UPDATE" then
            -- Event Bucketing: Coalesce rapid-fire BAG_UPDATE events
            -- This reduces updates from ~50/sec to ~10/sec during looting
            if not Inventory.updatePending then
                Inventory.updatePending = true
                C_Timer.After(Inventory.bucketDelay, function()
                    Inventory:ScanBags()
                    if NS.Frames then NS.Frames:Update() end
                    Inventory.updatePending = false
                end)
            end
        elseif event == "PLAYER_MONEY" then
            -- Update money display
            if NS.Frames and NS.Frames.mainFrame and NS.Frames.mainFrame:IsShown() then
                NS.Frames:UpdateMoney()
            end
        end
    end)
    self:ScanBags()
end

function Inventory:ScanBags()
    wipe(self.items)
    local newState = {}
    
    -- Helper to scan a list of bags
    local function scanList(bagList, locationType)
        for _, bagID in ipairs(bagList) do
            local numSlots = GetContainerNumSlots(bagID)
            for slotID = 1, numSlots do
                local texture, count, locked, quality, readable, lootable, link, isFiltered, noValue, itemID = GetContainerItemInfo(bagID, slotID)
                
                local key = bagID .. ":" .. slotID
                
                -- Track current state
                if link then
                    newState[key] = {
                        link = link,
                        count = count,
                        texture = texture
                    }
                    
                    table.insert(self.items, {
                        bagID = bagID,
                        slotID = slotID,
                        link = link,
                        texture = texture,
                        count = count,
                        quality = quality,
                        itemID = itemID,
                        location = locationType, -- "bags", "bank", "keyring"
                        category = NS.Categories:GetCategory(link)
                    })
                end
                
                -- Compare with previous state to detect changes
                local prev = self.previousState[key]
                local curr = newState[key]
                
                -- Mark dirty if changed
                if not prev and curr then
                    -- New item
                    self:MarkDirty(bagID, slotID)
                elseif prev and not curr then
                    -- Item removed
                    self:MarkDirty(bagID, slotID)
                elseif prev and curr then
                    -- Check if item changed (different link or count)
                    if prev.link ~= curr.link or prev.count ~= curr.count then
                        self:MarkDirty(bagID, slotID)
                    end
                end
            end
        end
    end

    scanList(BAGS, "bags")
    -- scanList({KEYRING}, "keyring") 
    -- scanList(BANK, "bank")
    
    -- Update previous state for next comparison
    self.previousState = newState
    
    -- Sort
    table.sort(self.items, function(a, b) return NS.Categories:CompareItems(a, b) end)

    -- Save to DB for offline viewing
    if ZenBagsDB then
        local charKey = UnitName("player") .. " - " .. GetRealmName()
        ZenBagsDB.characters = ZenBagsDB.characters or {}
        ZenBagsDB.characters[charKey] = self.items
    end
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
