local addonName, OI = ...
OI.Config = {}
local Config = OI.Config

local OPTIONS_TABLE = {
    type = "group",
    name = "OmniInventory",
    args = {
        general = {
            type = "group",
            name = "General",
            inline = true,
            args = {
                scale = {
                    type = "range",
                    name = "Scale",
                    desc = "Frame scale",
                    min = 0.5, max = 2.0, step = 0.05,
                    get = function() return OI.db.char.settings and OI.db.char.settings.scale or 1 end,
                    set = function(_, v) if OI.Frame then OI.Frame:SetScale(v) end end,
                },
                showBagSlots = {
                    type = "toggle",
                    name = "Show Bag Slots",
                    desc = "Show bag slot panel",
                    get = function() return OI.db.global.showBagSlots end,
                    set = function(_, v) OI.db.global.showBagSlots = v; if OI.Frame then OI.Frame:ForceRender() end end,
                },
                showMinimap = {
                    type = "toggle",
                    name = "Show Minimap Button",
                    get = function() return OI.db.global.showMinimap end,
                    set = function(_, v)
                        OI.db.global.showMinimap = v
                        if OI.MinimapButton then
                            if v then OI.MinimapButton:Show() else OI.MinimapButton:Hide() end
                        end
                    end,
                },
                autoSortOnClose = {
                    type = "toggle",
                    name = "Auto Sort on Close",
                    desc = "Sort bags when frame closes",
                    get = function() return OI.db.global.autoSortOnClose end,
                    set = function(_, v) OI.db.global.autoSortOnClose = v end,
                },
                showItemLevel = {
                    type = "toggle",
                    name = "Show Item Level",
                    desc = "Show item level on equipment",
                    get = function() return OI.db.global.showItemLevel end,
                    set = function(_, v) OI.db.global.showItemLevel = v; if OI.Frame then OI.Frame:ForceRender() end end,
                },
                columns = {
                    type = "range",
                    name = "Columns",
                    desc = "Number of item columns",
                    min = 5, max = 20, step = 1,
                    get = function() return OI.db.global.columns end,
                    set = function(_, v) OI.db.global.columns = v; if OI.Frame then OI.Frame:ForceRender() end end,
                },
                resetPosition = {
                    type = "execute",
                    name = "Reset Position",
                    desc = "Reset frame position",
                    func = function() if OI.Frame then OI.Frame:ResetPosition() end end,
                },
            },
        },
        sort = {
            type = "group",
            name = "Sorting",
            inline = true,
            args = {
                sortMode = {
                    type = "select",
                    name = "Default Sort",
                    values = {
                        category = "Category",
                        quality = "Quality",
                        name = "Name",
                        ilvl = "Item Level",
                    },
                    get = function() return OI.db.global.sortMode end,
                    set = function(_, v) OI.db.global.sortMode = v end,
                },
            },
        },
    },
}

function Config:Open()
    if not LibStub("AceConfigDialog-3.0", true) then
        OI:Print("AceConfig-3.0 not loaded.")
        return
    end
    LibStub("AceConfigDialog-3.0"):Open("OmniInventory")
end

function Config:Init()
    local AceConfig = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if AceConfig and AceConfigDialog then
        AceConfig:RegisterOptionsTable("OmniInventory", OPTIONS_TABLE)
        AceConfigDialog:AddToBlizOptions("OmniInventory", "OmniInventory")

        OI:RegisterChatCommand("omniconfig", function() self:Open() end)
        OI:RegisterChatCommand("oiconfig", function() self:Open() end)
    end
end

print("|cFF00FF00OmniInventory|r: Config loaded")
