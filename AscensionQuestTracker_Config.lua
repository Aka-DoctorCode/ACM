--------------------------------------------------------------------------------
-- CONFIGURATION MODULE (AceConfig-3.0)
--------------------------------------------------------------------------------
local addonName, addonTable = ...
local L = LibStub("AceLocale-3.0"):GetLocale("AscensionQuestTracker", true)

-- 1. Default Settings
local defaults = {
    testMode = false,
    position = { point = "RIGHT", relativePoint = "RIGHT", x = -50, y = 0 },
    scale = 1.0,
    hideOnBoss = true,
    width = 260,
    locked = false,
    hideBlizzardTracker = true,
    showAllZoneHeaders = false,
    barSpacing = 16,
    
    -- Scenario / Bonus Objectives Defaults
    scenario = {
        titleSize = 13,
        descSize = 10,
        objSize = 10,
        barHeight = 4,
        barColor = {r = 1, g = 0.85, b = 0.3, a = 1}
    },

    -- World Quest Defaults
    worldQuest = {
        titleSize = 13,
        descSize = 10,
        objSize = 10,
        barHeight = 4,
        barColor = {r = 0.3, g = 0.7, b = 1, a = 1},
        titleColor = {r = 0.3, g = 0.7, b = 1, a = 1}
    },

    -- Quest Defaults
    quest = {
        titleSize = 13,
        descSize = 10,
        objSize = 10,
        barHeight = 4,
        barColor = {r = 1, g = 0.85, b = 0.3, a = 1},
        titleColor = {r = 1, g = 0.85, b = 0.3, a = 1}
    },
    
    -- Focused Quest Defaults (General)
    focused = {
        titleColor = {r = 1, g = 1, b = 1, a = 1},
        barColor = {r = 1, g = 1, b = 1, a = 1}
    }
}

-- 2. Database Handling (SavedVariables)
function addonTable.LoadDatabase()
    -- Create DB if it doesn't exist
    if not AscensionQuestTrackerDB then
        AscensionQuestTrackerDB = {}
    end
    
    -- Populate missing root defaults
    for key, value in pairs(defaults) do
        if key ~= "scenario" and key ~= "worldQuest" and key ~= "focused" and AscensionQuestTrackerDB[key] == nil then
            AscensionQuestTrackerDB[key] = value
        end
    end
    
    -- Populate scenario defaults
    if not AscensionQuestTrackerDB.scenario then
        AscensionQuestTrackerDB.scenario = {}
    end
    for key, value in pairs(defaults.scenario) do
        if AscensionQuestTrackerDB.scenario[key] == nil then
            AscensionQuestTrackerDB.scenario[key] = value
        end
    end

    -- Populate worldQuest defaults
    if not AscensionQuestTrackerDB.worldQuest then
        AscensionQuestTrackerDB.worldQuest = {}
    end
    for key, value in pairs(defaults.worldQuest) do
        if AscensionQuestTrackerDB.worldQuest[key] == nil then
            AscensionQuestTrackerDB.worldQuest[key] = value
        end
    end

    -- Populate quest defaults
    if not AscensionQuestTrackerDB.quest then
        AscensionQuestTrackerDB.quest = {}
    end
    for key, value in pairs(defaults.quest) do
        if AscensionQuestTrackerDB.quest[key] == nil then
            AscensionQuestTrackerDB.quest[key] = value
        end
    end

    -- Populate focused defaults
    if not AscensionQuestTrackerDB.focused then
        AscensionQuestTrackerDB.focused = {}
    end
    for key, value in pairs(defaults.focused) do
        if AscensionQuestTrackerDB.focused[key] == nil then
            AscensionQuestTrackerDB.focused[key] = value
        end
    end
    
    -- Deep copy for position if missing
    if not AscensionQuestTrackerDB.position then
        AscensionQuestTrackerDB.position = defaults.position
    end
    
    -- Force Test Mode to false on load (do not persist)
    AscensionQuestTrackerDB.testMode = false
end

-- 3. Options Table
local options = {
    type = "group",
    name = L["Ascension Quest Tracker"],
    handler = addonTable,
    childGroups = "tab", -- Enable Tabs
    args = {
        testMode = {
            type = "toggle",
            name = L["Test Mode"],
            desc = L["Enable Test Mode to preview changes with fake data"],
            get = function() return AscensionQuestTrackerDB.testMode end,
            set = function(_, val) 
                AscensionQuestTrackerDB.testMode = val
                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                     AscensionQuestTrackerFrame:FullUpdate()
                end
            end,
            order = 0, -- Top priority
            width = "full",
        },
        general = {
            type = "group",
            name = L["General"],
            order = 1,
            args = {
                header = {
                    type = "header",
                    name = L["Settings"],
                    order = 0,
                },
                hideOnBoss = {
                    type = "toggle",
                    name = L["Hide Quests during Boss Encounters"],
                    desc = L["Hide Quests during Boss Encounters"],
                    get = function() return AscensionQuestTrackerDB.hideOnBoss end,
                    set = function(_, val) 
                        AscensionQuestTrackerDB.hideOnBoss = val
                        if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                             AscensionQuestTrackerFrame:FullUpdate()
                        end
                    end,
                    order = 1,
                },
                locked = {
                    type = "toggle",
                    name = L["Lock Position"],
                    desc = L["Lock Position"],
                    get = function() return AscensionQuestTrackerDB.locked end,
                    set = function(_, val) 
                        AscensionQuestTrackerDB.locked = val
                        if AscensionQuestTrackerFrame then
                             AscensionQuestTrackerFrame:EnableMouse(not val)
                        end
                    end,
                    order = 2,
                },
                hideBlizzard = {
                     type = "toggle",
                     name = L["Hide Blizzard Quest Tracker"],
                     desc = L["Hide Blizzard Quest Tracker"],
                     get = function() return AscensionQuestTrackerDB.hideBlizzardTracker end,
                     set = function(_, val)
                         AscensionQuestTrackerDB.hideBlizzardTracker = val
                         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.UpdateBlizzardTrackerVisibility then
                             AscensionQuestTrackerFrame:UpdateBlizzardTrackerVisibility()
                         end
                     end,
                     order = 3,
                },
                showZoneHeaders = {
                    type = "toggle",
                    name = L["Show All Zone Headers"],
                    desc = L["Show All Zone Headers"],
                    get = function() return AscensionQuestTrackerDB.showAllZoneHeaders end,
                    set = function(_, val)
                        AscensionQuestTrackerDB.showAllZoneHeaders = val
                        if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                            AscensionQuestTrackerFrame:FullUpdate()
                        end
                    end,
                    order = 4,
                },
                scale = {
                    type = "range",
                    name = L["Tracker Scale"],
                    desc = L["Tracker Scale"],
                    min = 0.5,
                    max = 2.0,
                    step = 0.1,
                    get = function() return AscensionQuestTrackerDB.scale or 1.0 end,
                    set = function(_, val)
                        AscensionQuestTrackerDB.scale = val
                        if AscensionQuestTrackerFrame then
                            AscensionQuestTrackerFrame:SetScale(val)
                        end
                    end,
                    order = 5,
                },
                width = {
                    type = "range",
                    name = L["Tracker Width"],
                    desc = L["Tracker Width"],
                    min = 200,
                    max = 500,
                    step = 10,
                    get = function() return AscensionQuestTrackerDB.width or 260 end,
                    set = function(_, val)
                        AscensionQuestTrackerDB.width = val
                        if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                            AscensionQuestTrackerFrame:FullUpdate()
                        end
                    end,
                    order = 6,
                },
                barSpacing = {
                    type = "range",
                    name = L["Progress Bar Spacing"],
                    desc = L["Progress Bar Spacing"],
                    min = 2,
                    max = 20,
                    step = 1,
                    get = function() return AscensionQuestTrackerDB.barSpacing or 8 end,
                    set = function(_, val)
                        AscensionQuestTrackerDB.barSpacing = val
                        if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                            AscensionQuestTrackerFrame:FullUpdate()
                        end
                    end,
                    order = 7,
                },
                focusedOptions = {
                    type = "group",
                    name = L["Focus / SuperTrack"],
                    order = 8,
                    inline = true,
                    args = {
                         header = {
                             type = "header",
                             name = L["Focus Settings"],
                             order = 0,
                         },
                         titleColor = {
                             type = "color",
                             name = L["Title Color"],
                             get = function() 
                                 local c = AscensionQuestTrackerDB.focused.titleColor
                                 return c.r, c.g, c.b, c.a
                             end,
                             set = function(_, r, g, b, a) 
                                 AscensionQuestTrackerDB.focused.titleColor = {r = r, g = g, b = b, a = a}
                                 if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                     AscensionQuestTrackerFrame:FullUpdate()
                                 end
                             end,
                             order = 1,
                         },
                         barColor = {
                             type = "color",
                             name = L["Bar Color"],
                             get = function() 
                                 local c = AscensionQuestTrackerDB.focused.barColor
                                 return c.r, c.g, c.b, c.a
                             end,
                             set = function(_, r, g, b, a) 
                                 AscensionQuestTrackerDB.focused.barColor = {r = r, g = g, b = b, a = a}
                                 if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                     AscensionQuestTrackerFrame:FullUpdate()
                                 end
                             end,
                             order = 2,
                         },
                    }
                },
                description = {
                    type = "description",
                    name = "\n" .. L["Note: To move the tracker, ensure 'Lock Position' is unchecked.\nDrag the tracker with Left Click."],
                    order = 10,
                    fontSize = "medium",
                }
            }
        },
        scenario = {
            type = "group",
            name = L["Scenario"],
            order = 2,
            args = {
                header = {
                    type = "header",
                    name = L["Scenario Settings"],
                    order = 0,
                },
                desc = {
                    type = "description",
                    name = L["Customize the scenario event frame of your Ascension tracker"],
                    order = 1,
                    fontSize = "medium",
                },
                textOptions = {
                    type = "group",
                    name = L["Text Size"],
                    order = 2,
                    inline = true,
                    args = {
                        titleSize = {
                            type = "range",
                            name = L["Title"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.scenario.titleSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.scenario.titleSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                        descSize = {
                            type = "range",
                            name = L["Description"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.scenario.descSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.scenario.descSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 2,
                        },
                        objSize = {
                            type = "range",
                            name = L["Objectives"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.scenario.objSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.scenario.objSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 3,
                        },
                    }
                },
                barOptions = {
                    type = "group",
                    name = L["Progress Bar"],
                    order = 3,
                    inline = true,
                    args = {
                        barHeight = {
                            type = "range",
                            name = L["Height"],
                            min = 1, max = 20, step = 1,
                            get = function() return AscensionQuestTrackerDB.scenario.barHeight end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.scenario.barHeight = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                        barColor = {
                            type = "color",
                            name = L["Color"],
                            get = function() 
                                local c = AscensionQuestTrackerDB.scenario.barColor
                                return c.r, c.g, c.b, c.a
                            end,
                            set = function(_, r, g, b, a) 
                                AscensionQuestTrackerDB.scenario.barColor = {r = r, g = g, b = b, a = a}
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 2,
                        },
                    }
                }
            }
        },
        worldQuest = {
            type = "group",
            name = L["World Quest"],
            order = 3,
            args = {
                header = {
                    type = "header",
                    name = L["World Quest Settings"],
                    order = 0,
                },
                desc = {
                    type = "description",
                    name = L["Customize the world quest frame of your Ascension tracker"],
                    order = 1,
                    fontSize = "medium",
                },
                textOptions = {
                    type = "group",
                    name = L["Text Size"],
                    order = 2,
                    inline = true,
                    args = {
                        titleSize = {
                            type = "range",
                            name = L["Title"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.worldQuest.titleSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.worldQuest.titleSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                        descSize = {
                            type = "range",
                            name = L["Description"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.worldQuest.descSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.worldQuest.descSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 2,
                        },
                        objSize = {
                            type = "range",
                            name = L["Objectives"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.worldQuest.objSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.worldQuest.objSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 3,
                        },
                    }
                },
                colorOptions = {
                    type = "group",
                    name = L["Colors"],
                    order = 3,
                    inline = true,
                    args = {
                        titleColor = {
                            type = "color",
                            name = L["Title Color"],
                            get = function() 
                                local c = AscensionQuestTrackerDB.worldQuest.titleColor
                                return c.r, c.g, c.b, c.a
                            end,
                            set = function(_, r, g, b, a) 
                                AscensionQuestTrackerDB.worldQuest.titleColor = {r = r, g = g, b = b, a = a}
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                        barColor = {
                            type = "color",
                            name = L["Bar Color"],
                            get = function() 
                                local c = AscensionQuestTrackerDB.worldQuest.barColor
                                return c.r, c.g, c.b, c.a
                            end,
                            set = function(_, r, g, b, a) 
                                AscensionQuestTrackerDB.worldQuest.barColor = {r = r, g = g, b = b, a = a}
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 2,
                        },
                    }
                },
                barOptions = {
                    type = "group",
                    name = L["Progress Bar"],
                    order = 4,
                    inline = true,
                    args = {
                        barHeight = {
                            type = "range",
                            name = L["Height"],
                            min = 1, max = 20, step = 1,
                            get = function() return AscensionQuestTrackerDB.worldQuest.barHeight end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.worldQuest.barHeight = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                    }
                }
            }
        },
        quest = {
            type = "group",
            name = L["Quests"],
            order = 4,
            args = {
                header = {
                    type = "header",
                    name = L["Quest Settings"],
                    order = 0,
                },
                desc = {
                    type = "description",
                    name = L["Customize the quest frame of your Ascension tracker"],
                    order = 1,
                    fontSize = "medium",
                },
                textOptions = {
                    type = "group",
                    name = L["Text Size"],
                    order = 2,
                    inline = true,
                    args = {
                        titleSize = {
                            type = "range",
                            name = L["Title"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.quest.titleSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.quest.titleSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                        descSize = {
                            type = "range",
                            name = L["Description"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.quest.descSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.quest.descSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 2,
                        },
                        objSize = {
                            type = "range",
                            name = L["Objectives"],
                            min = 8, max = 30, step = 1,
                            get = function() return AscensionQuestTrackerDB.quest.objSize end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.quest.objSize = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 3,
                        },
                    }
                },
                colorOptions = {
                    type = "group",
                    name = L["Colors"],
                    order = 3,
                    inline = true,
                    args = {
                        titleColor = {
                            type = "color",
                            name = L["Title Color"],
                            get = function() 
                                local c = AscensionQuestTrackerDB.quest.titleColor
                                return c.r, c.g, c.b, c.a
                            end,
                            set = function(_, r, g, b, a) 
                                AscensionQuestTrackerDB.quest.titleColor = {r = r, g = g, b = b, a = a}
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                        barColor = {
                            type = "color",
                            name = L["Bar Color"],
                            get = function() 
                                local c = AscensionQuestTrackerDB.quest.barColor
                                return c.r, c.g, c.b, c.a
                            end,
                            set = function(_, r, g, b, a) 
                                AscensionQuestTrackerDB.quest.barColor = {r = r, g = g, b = b, a = a}
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 2,
                        },
                    }
                },
                barOptions = {
                    type = "group",
                    name = L["Progress Bar"],
                    order = 4,
                    inline = true,
                    args = {
                        barHeight = {
                            type = "range",
                            name = L["Height"],
                            min = 1, max = 20, step = 1,
                            get = function() return AscensionQuestTrackerDB.quest.barHeight end,
                            set = function(_, val) 
                                AscensionQuestTrackerDB.quest.barHeight = val
                                if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
                                    AscensionQuestTrackerFrame:FullUpdate()
                                end
                            end,
                            order = 1,
                        },
                    }
                }
            }
        }
    }
}

-- Initialize Config on Login
local configLoader = CreateFrame("Frame")
configLoader:RegisterEvent("PLAYER_LOGIN")
configLoader:SetScript("OnEvent", function()
    addonTable.LoadDatabase()
    
    -- Register AceConfig Options
    LibStub("AceConfig-3.0"):RegisterOptionsTable("AscensionQuestTracker", options)
    local dialog = LibStub("AceConfigDialog-3.0")
    dialog:AddToBlizOptions("AscensionQuestTracker", "Ascension QT")
end)