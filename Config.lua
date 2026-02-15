-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Config.lua
-- Version: 07
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, ns = ...
local AQT = ns.AQT or {}
ns.AQT = AQT
local ASSETS = ns.ASSETS

-- Helper to create a style group (Now strictly for Tabs)
local function CreateStyleGroup(key, name, order, db)
    return {
        type = "group",
        name = name,
        order = order,
        args = {
            header = {
                type = "header", 
                name = name .. " Settings",
                order = 0,
            },
            titleSize = {
                type = "range", name = "Title Font Size", min = 10, max = 30, step = 1, order = 1,
                width = "full", -- Replaced headerSize
                get = function() return db.profile.styles[key].titleSize end,
                set = function(_, val) db.profile.styles[key].titleSize = val; AQT:FullUpdate() end,
            },
            descSize = {
                type = "range", name = "Description Font Size", min = 8, max = 24, step = 1, order = 2,
                width = "full", -- Replaced textSize
                get = function() return db.profile.styles[key].descSize end,
                set = function(_, val) db.profile.styles[key].descSize = val; AQT:FullUpdate() end,
            },
            objSize = {
                type = "range", name = "Objectives Font Size", min = 8, max = 24, step = 1, order = 2.5,
                width = "full", -- New
                get = function() return db.profile.styles[key].objSize end,
                set = function(_, val) db.profile.styles[key].objSize = val; AQT:FullUpdate() end,
            },
            barHeight = {
                type = "range", name = "Bar Height", min = 2, max = 20, step = 1, order = 3,
                width = "full",
                get = function() return db.profile.styles[key].barHeight end,
                set = function(_, val) db.profile.styles[key].barHeight = val; AQT:FullUpdate() end,
            },
            lineSpacing = {
                type = "range", name = "Line Spacing", min = 0, max = 20, step = 1, order = 4,
                width = "full",
                get = function() return db.profile.styles[key].lineSpacing end,
                set = function(_, val) db.profile.styles[key].lineSpacing = val; AQT:FullUpdate() end,
            },
            -- Per-Module Colors
            h_cols = { type = "header", name = "Module Colors", order = 10 },
            titleColor = {
                type = "color", name = "Title Color", order = 11, hasAlpha = true,
                get = function() local c = db.profile.styles[key].titleColor; return c.r, c.g, c.b, c.a end,
                set = function(_, r, g, b, a) db.profile.styles[key].titleColor = {r=r, g=g, b=b, a=a}; AQT:FullUpdate() end,
            },
            barColor = {
                type = "color", name = "Bar Color", order = 12, hasAlpha = true,
                get = function() local c = db.profile.styles[key].barColor; return c.r, c.g, c.b, c.a end,
                set = function(_, r, g, b, a) db.profile.styles[key].barColor = {r=r, g=g, b=b, a=a}; AQT:FullUpdate() end,
            },
        }
    }
end

local function CreateColorOption(key, name, order, db)
    return {
        type = "color",
        name = name,
        order = order,
        hasAlpha = false,
        get = function() 
            local c = db.profile.colors[key]
            return c.r, c.g, c.b, c.a 
        end,
        set = function(_, r, g, b, a) 
            local c = db.profile.colors[key]
            c.r, c.g, c.b, c.a = r, g, b, a
            AQT:FullUpdate()
        end,
    }
end

-- Options Table Definition
function AQT:GetOptions()
    local options = {
        name = "Ascension Quest Tracker",
        handler = AQT,
        type = "group",
        childGroups = "tab", -- Enables Tabs
        args = {
            general = {
                type = "group", name = "General", order = 1,
                args = {
                    header = { type = "header", name = "General Settings", order = 0 },
                    
                    -- Toggles
                    testMode = {
                        type = "toggle", name = "Test Mode", desc = "Show mock data to configure visuals.", order = 1,
                        get = function() return self.db.profile.testMode end,
                        set = function(_, val) self.db.profile.testMode = val; self:FullUpdate() end,
                    },
                    hideBlizzard = {
                        type = "toggle", name = "Hide Blizzard Tracker", desc = "Hides the default quest tracker.", order = 1.1,
                        get = function() return self.db.profile.hideBlizzardTracker end,
                        set = function(_, val) 
                            self.db.profile.hideBlizzardTracker = val
                            self:UpdateBlizzardTrackerVisibility()
                        end,
                    },
                    locked = {
                        type = "toggle", name = "Lock Position", order = 1.2,
                        get = function() return self.db.profile.locked end,
                        set = function(_, val) self.db.profile.locked = val; if self.Container then self.Container:EnableMouse(not val) end end,
                    },
                    hideOnBoss = {
                        type = "toggle", name = "Hide on Boss", desc = "Automatically hide during boss encounters.", order = 1.3,
                        get = function() return self.db.profile.hideOnBoss end,
                        set = function(_, val) self.db.profile.hideOnBoss = val; self:FullUpdate() end,
                    },
                    autoSuperTrack = {
                        type = "toggle", name = "Auto Super Track", desc = "Automatically track the nearest quest.", order = 1.31,
                        get = function() return self.db.profile.autoSuperTrack end,
                        set = function(_, val) self.db.profile.autoSuperTrack = val; self:FullUpdate() end,
                    },
                    showAllZoneHeaders = {
                        type = "toggle", name = "Show Zone Headers", 
                        desc = "Group side quests by zone with headers. If disabled, shows a flat list.", 
                        order = 1.35,
                        get = function() return self.db.profile.showAllZoneHeaders end,
                        set = function(_, val) self.db.profile.showAllZoneHeaders = val; self:FullUpdate() end,
                    },
                    -- Sliders
                    scale = {
                        type = "range", name = "Global Scale", min = 0.5, max = 2.0, step = 0.1, order = 2,
                        width = "full",
                        get = function() return self.db.profile.scale end,
                        set = function(_, val) self.db.profile.scale = val; self:UpdateLayout() end,
                    },
                    width = {
                        type = "range", name = "Tracker Width", min = 200, max = 600, step = 10, order = 3,
                        width = "full",
                        get = function() return self.db.profile.width end,
                        set = function(_, val) self.db.profile.width = val; self:FullUpdate() end,
                    },
                    maxHeight = { -- <--- RE-ADDED THIS SLIDER
                        type = "range", name = "Max Height", desc = "Maximum height before scrolling becomes active.", 
                        min = 200, max = 1500, step = 10, order = 4,
                        width = "full",
                        get = function() return self.db.profile.maxHeight end,
                        set = function(_, val) self.db.profile.maxHeight = val; self:FullUpdate() end,
                    },
                    sectionSpacing = {
                        type = "range", name = "Module Spacing", min = 0, max = 50, step = 1, order = 5,
                        width = "full",
                        get = function() return self.db.profile.sectionSpacing end,
                        set = function(_, val) self.db.profile.sectionSpacing = val; self:FullUpdate() end,
                    },
                    colors = {
                        type = "group", name = "Colors", order = 2,
                        args = {
                            header = { type = "header", name = "Global Colors", order = 0 },
                            
                            headerColor = CreateColorOption("header", "Section Headers", 1, self.db),
                            zoneColor = CreateColorOption("zone", "Zone Names", 2, self.db),
                            questColor = CreateColorOption("quest", "Quest Titles (Normal)", 3, self.db),
                            completeColor = CreateColorOption("complete", "Completed Quests", 4, self.db),
                            campaignColor = CreateColorOption("campaign", "Campaign Quests", 5, self.db),
                            wqColor = CreateColorOption("wq", "World Quests", 6, self.db),
                            achColor = CreateColorOption("achievement", "Achievements", 7, self.db),
                            sideQuestColor = CreateColorOption("sideQuest", "Objective Bars", 8, self.db),
                        }
                    },
                    focusedOptions = {
                        type = "group", name = "Focus / SuperTrack", order = 3, inline = true,
                        args = {
                             header = { type = "header", name = "Focus Settings", order = 0 },
                             titleColor = {
                                 type = "color", name = "Title Color", 
                                 get = function() local c = self.db.profile.focused.titleColor; return c.r, c.g, c.b, c.a end,
                                 set = function(_, r, g, b, a) self.db.profile.focused.titleColor = {r=r, g=g, b=b, a=a}; self:FullUpdate() end,
                                 order = 1,
                             },
                             barColor = {
                                 type = "color", name = "Bar Color", 
                                 get = function() local c = self.db.profile.focused.barColor; return c.r, c.g, c.b, c.a end,
                                 set = function(_, r, g, b, a) self.db.profile.focused.barColor = {r=r, g=g, b=b, a=a}; self:FullUpdate() end,
                                 order = 2,
                             },
                        }
                    },
                },
            },
            
            -- Modular Style Tabs
            scenarios = CreateStyleGroup("scenarios", "Dungeons", 2, self.db),
            quests = CreateStyleGroup("quests", "Quests", 3, self.db),
            worldQuests = CreateStyleGroup("worldQuests", "World Quests", 4, self.db),
            achievements = CreateStyleGroup("achievements", "Achievements", 5, self.db),
            
            -- Profiles Tab
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
        },
    }
    
    -- Adjust Profiles Tab Order
    options.args.profiles.order = 100
    
    return options
end

function AQT:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("AscensionQuestTracker", self:GetOptions())
    
    -- Capture the categoryID
    local optionsFrame, categoryID = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AscensionQuestTracker", "Ascension Quest Tracker")
    self.optionsFrame = optionsFrame
    
    self:RegisterChatCommand("aqt", function() 
        if categoryID then
            if Settings and Settings.OpenToCategory then
                -- Try passing the category ID first
                local success = pcall(Settings.OpenToCategory, categoryID)
                if not success then
                    -- Fallback to searching by name if ID fails
                    pcall(Settings.OpenToCategory, "Ascension Quest Tracker")
                end
            elseif InterfaceOptionsFrame_OpenToCategory then
                InterfaceOptionsFrame_OpenToCategory(categoryID)
            end
        else
            -- Check if Settings exists
            if Settings and Settings.OpenToCategory then
                Settings.OpenToCategory("Ascension Quest Tracker")
            end
        end
    end)
end
