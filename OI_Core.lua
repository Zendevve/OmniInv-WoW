-- =============================================================================
-- OmniInventory Core (Ace3 Addon Object)
-- =============================================================================
-- Main entry point. Ace3 framework, saved vars, module init, Blizzard hooks.
-- =============================================================================

local addonName, ns = ...

-- =============================================================================
-- Ace3 Bootstrap
-- =============================================================================

local OI = LibStub("AceAddon-3.0"):NewAddon(
    addonName,
    "AceEvent-3.0",
    "AceConsole-3.0",
    "AceTimer-3.0",
    "AceHook-3.0"
)

ns[1] = OI
_G.OmniInventory = OI

OI.version = "2.0-alpha"
OI.author = "Zendevve"
OI.addonName = addonName

-- =============================================================================
-- Defaults
-- =============================================================================

local defaults = {
    global = {
        viewMode = "flow",
        sortMode = "category",
        columns = 10,
        itemSize = 37,
        scale = 1.0,
        opacity = 0.95,
        showBagSlots = true,
        showMinimap = true,
        autoSortOnClose = false,
        pinnedItems = {},
    },
    char = {
        position = nil,
        customRules = {},
        collapsedCategories = {},
        settings = {
            scale = 1.0,
        },
    },
    realm = {},
    profile = "default",
}

-- =============================================================================
-- Saved Variables Migration
-- =============================================================================

local function MigrateOldDB()
    if not OmniInventoryDB then return end

    if OmniInventoryDB.global then
        for k, v in pairs(defaults.global) do
            if OmniInventoryDB.global[k] == nil then
                OmniInventoryDB.global[k] = v
            end
        end
    end
end

-- =============================================================================
-- Init
-- =============================================================================

function OI:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("OmniInventoryDB", defaults, true)
    MigrateOldDB()

    local realmName = GetRealmName()
    local playerName = UnitName("player")

    self.db.realm[realmName] = self.db.realm[realmName] or {}
    self.db.realm[realmName][playerName] = self.db.realm[realmName][playerName] or {
        class = select(2, UnitClass("player")),
        lastSeen = time(),
        gold = 0,
        bags = {},
        bank = {},
        keyring = {},
        stockSnapshot = {},
    }

    self.charKey = realmName .. "-" .. playerName
    self.realmName = realmName
    self.playerName = playerName

    if self.API then self.API:Init() end
    if self.Data then self.Data:Init() end
    if self.Categorizer then self.Categorizer:Init() end
    if self.Sorter then self.Sorter:Init() end
    if self.Rules then self.Rules:Init() end
    if self.Filter then self.Filter:Init() end

    self:Print("v" .. self.version .. " loaded.")
end

function OI:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN")
end

function OI:PLAYER_LOGIN()
    if self.Pool then self.Pool:Init() end
    if self.Frame then self.Frame:Init() end
    if self.Bank then self.Bank:Init() end
    if self.MinimapButton then self.MinimapButton:Init() end
    if self.Tooltips then self.Tooltips:Init() end
    if self.Junk then self.Junk:Init() end
    if self.Config then self.Config:Init() end

    self:HookBlizzardBags()
    self:DetectIntegrations()

    self:ScheduleTimer(function()
        if self.Categorizer then self.Categorizer:SnapshotInventory() end
        if self.Data then self.Data:SaveCharacterInventory() end
    end, 2)
end

-- =============================================================================
-- Blizzard Bag Hooks (100ms debounce)
-- =============================================================================

local lastToggleTime = 0
local TOGGLE_DEBOUNCE = 0.1

local function SafeToggle()
    local now = GetTime()
    if now - lastToggleTime < TOGGLE_DEBOUNCE then return end
    lastToggleTime = now
    if OI.Frame then OI.Frame:Toggle() end
end

function OI:HookBlizzardBags()
    self:RawHook("ToggleAllBags", function() SafeToggle() end, true)
    self:RawHook("OpenAllBags", function() if OI.Frame then OI.Frame:Show() end end, true)
    self:RawHook("CloseAllBags", function() if OI.Frame then OI.Frame:Hide() end end, true)
    self:RawHook("ToggleBackpack", function() SafeToggle() end, true)
    self:RawHook("OpenBackpack", function() if OI.Frame then OI.Frame:Show() end end, true)
    self:RawHook("CloseBackpack", function() if OI.Frame then OI.Frame:Hide() end end, true)
    self:RawHook("ToggleBag", function() SafeToggle() end, true)
    self:RawHook("OpenBag", function() if OI.Frame then OI.Frame:Show() end end, true)

    self:Hook("ToggleKeyRing", function()
        if OI.Frame then
            if OI.Frame:IsShown() and OI.Frame:GetMode() == "keys" then
                OI.Frame:Hide()
            else
                OI.Frame:SetMode("keys")
                OI.Frame:Show()
            end
        end
    end, true)

    for i = 1, 13 do
        local f = _G["ContainerFrame" .. i]
        if f then
            f:Hide()
            f:UnregisterAllEvents()
            f:SetScript("OnShow", function(self) self:Hide() end)
        end
    end

    for i = 0, 4 do
        local f = _G["ContainerFrame" .. (i + 1)]
        if f then f:Hide() end
    end
end

-- =============================================================================
-- Integrations
-- =============================================================================

function OI:DetectIntegrations()
    self.integrations = {}
    if Pawn then table.insert(self.integrations, "Pawn") end
    if Auctionator then table.insert(self.integrations, "Auctionator") end

    local LDB = LibStub("LibDataBroker-1.1", true)
    if LDB then
        table.insert(self.integrations, "LibDataBroker")
        self:LDB_Create()
    end

    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then table.insert(self.integrations, "LibSharedMedia") end

    if #self.integrations > 0 then
        self:Print("Integrations: " .. table.concat(self.integrations, ", "))
    end
end

-- =============================================================================
-- LDB Launcher
-- =============================================================================

function OI:LDB_Create()
    local LDB = LibStub("LibDataBroker-1.1")
    if not LDB then return end

    self.ldbObj = LDB:NewDataObject(addonName, {
        type = "launcher",
        icon = "Interface\\Icons\\INV_Misc_Bag_07",
        label = "OmniInventory",
        OnClick = function(_, button)
            if button == "LeftButton" then
                if OI.Frame then OI.Frame:Toggle() end
            elseif button == "RightButton" then
                if OI.Config then OI.Config:Open() end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("|cFF00FF00Omni|rInventory " .. OI.version)
            tooltip:AddLine("|cFFFFFFFFLeft-click|r Toggle bags")
            tooltip:AddLine("|cFFFFFFFFRight-click|r Settings")
        end,
    })
end

-- =============================================================================
-- Slash Commands
-- =============================================================================

SLASH_OMNIINVENTORY1 = "/omniinventory"
SLASH_OMNIINVENTORY2 = "/omni"
SLASH_OMNIINVENTORY3 = "/oi"
SLASH_ZENBAGS1 = "/zb"
SLASH_ZENBAGS2 = "/zenbags"

SlashCmdList["OMNIINVENTORY"] = function(msg) OI:HandleSlash(msg) end
SlashCmdList["ZENBAGS"] = function(msg) OI:HandleSlash(msg) end

function OI:HandleSlash(msg)
    msg = strtrim(msg or ""):lower()

    if msg == "config" or msg == "settings" or msg == "options" then
        if self.Config then self.Config:Open() end
    elseif msg == "debug" then
        if self.Pool then self.Pool:Debug() end
    elseif msg == "reset" then
        if self.MinimapButton then self.MinimapButton:ResetPosition() end
        print("|cFF00FF00OmniInventory|r: Position reset.")
    elseif msg == "help" then
        self:Print("Commands:")
        print("  |cFFFFFF00/oi|r - Toggle bags")
        print("  |cFFFFFF00/oi config|r - Settings")
        print("  |cFFFFFF00/oi reset|r - Reset position")
    else
        if self.Frame then self.Frame:Toggle() end
    end
end

-- =============================================================================
-- Masque Support
-- =============================================================================

local Masque = LibStub("Masque", true)
if Masque then
    OI.MasqueGroup = Masque:Group(addonName)
end

print("|cFF00FF00OmniInventory|r: Core loaded")

-- =============================================================================
-- Message Bus (Ears-style)
-- =============================================================================

local listeners = {}

function OI:SendMessage(msg, ...)
    local lst = listeners[msg]
    if not lst then return end
    for obj, action in pairs(lst) do
        action(obj, ...)
    end
end

function OI:Listen(obj, msg, method)
    local method = method or msg
    local action
    if type(method) == "string" then
        action = obj[method]
        assert(action, "Object missing method: " .. method)
    else
        assert(type(method) == "function", "Function expected for method")
        action = method
    end
    listeners[msg] = listeners[msg] or {}
    listeners[msg][obj] = action
end

function OI:Ignore(obj, msg)
    local lst = listeners[msg]
    if lst then
        lst[obj] = nil
        if not next(lst) then listeners[msg] = nil end
    end
end
