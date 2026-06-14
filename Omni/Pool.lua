-- =============================================================================
-- OmniInventory Object Pool
-- =============================================================================
-- Recycle frames. Zero allocation during normal ops.
-- =============================================================================

local addonName, OI = ...

OI.Pool = {}
local Pool = OI.Pool

local pools = {}

local PoolMixin = {}

function PoolMixin:Acquire()
    local obj
    if #self.available > 0 then
        obj = table.remove(self.available)
    else
        obj = self.createFunc()
        self.totalCreated = self.totalCreated + 1
    end
    self.active[obj] = true
    self.activeCount = self.activeCount + 1
    return obj
end

function PoolMixin:Release(obj)
    if not self.active[obj] then return end
    if self.resetFunc then self.resetFunc(obj) end
    self.active[obj] = nil
    self.activeCount = self.activeCount - 1
    table.insert(self.available, obj)
end

function PoolMixin:ReleaseAll()
    for obj in pairs(self.active) do self:Release(obj) end
end

function PoolMixin:GetStats()
    return self.activeCount, #self.available, self.totalCreated
end

function PoolMixin:PreSpawn(count)
    if not count or count <= 0 then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for i = 1, count do
        local obj = self.createFunc()
        table.insert(self.available, obj)
        self.totalCreated = self.totalCreated + 1
    end
end

function Pool:Create(name, createFunc, resetFunc)
    if pools[name] then return pools[name] end
    local pool = {
        name = name, available = {}, active = {},
        activeCount = 0, totalCreated = 0,
        createFunc = createFunc, resetFunc = resetFunc,
    }
    for k, v in pairs(PoolMixin) do pool[k] = v end
    pools[name] = pool
    return pool
end

function Pool:Get(name) return pools[name] end

function Pool:Acquire(name)
    local pool = pools[name]
    return pool and pool:Acquire()
end

function Pool:Release(name, obj)
    local pool = pools[name]
    if pool then pool:Release(obj) end
end

function Pool:Debug()
    OI:Print("Pool Statistics:")
    for name, pool in pairs(pools) do
        local active, available, total = pool:GetStats()
        print(string.format("  %s: %d active, %d available, %d total", name, active, available, total))
    end
end

function Pool:Init()
    self:Create("ItemButton",
        function()
            if OI.ItemButton and OI.ItemButton.Create then
                local btn = OI.ItemButton:Create(UIParent)
                btn:Hide()
                if not btn.omniData then btn.omniData = {} end
                return btn
            end
            return CreateFrame("Button", nil, UIParent, "ItemButtonTemplate")
        end,
        function(btn)
            if OI.ItemButton and OI.ItemButton.Reset then OI.ItemButton:Reset(btn) end
            btn:Hide()
            btn:ClearAllPoints()
            btn:SetParent(UIParent)
        end
    )

    self:Create("CategoryHeader",
        function()
            local header = CreateFrame("Frame", nil, UIParent)
            header:SetHeight(20)
            header:Hide()
            header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.text:SetPoint("LEFT", 5, 0)
            header.count = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            header.count:SetPoint("RIGHT", -5, 0)
            header.count:SetTextColor(0.6, 0.6, 0.6)
            return header
        end,
        function(header)
            header:Hide()
            header:ClearAllPoints()
            header:SetParent(UIParent)
            header.text:SetText("")
            header.count:SetText("")
        end
    )

    local itemPool = self:Get("ItemButton")
    if itemPool then itemPool:PreSpawn(150) end
    local headerPool = self:Get("CategoryHeader")
    if headerPool then headerPool:PreSpawn(30) end
end

print("|cFF00FF00OmniInventory|r: Pool loaded")
