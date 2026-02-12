-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Themes.lua
-- Version: 05
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, AQT = ...

AQT.Themes = {
    Default = {
        font = "Fonts\\FRIZQT__.TTF",
        fontHeaderSize = 13,
        fontTextSize = 10,
        barTexture = "Interface\\Buttons\\WHITE8x8",
        barHeight = 4,
        padding = 10,
        spacing = 15,
        
        colors = {
            header = {r = 1, g = 0.9, b = 0.5}, -- Yellow
            timerHigh = {r = 1, g = 1, b = 1}, -- White
            timerLow = {r = 1, g = 0.2, b = 0.2}, -- Red
            campaign = {r = 1, g = 0.5, b = 0.25}, -- Orange
            quest = {r = 1, g = 0.85, b = 0.3}, -- Yellow
            wq = {r = 0.3, g = 0.7, b = 1}, -- Blue
            achievement = {r = 0.8, g = 0.8, b = 1}, -- Light Blue
            complete = {r = 0.2, g = 1, b = 0.2}, -- Green
            active = {r = 1, g = 1, b = 1}, -- White
            zone = {r = 1, g = 1, b = 0.6}, -- Zone Header
            
            -- Fallbacks/Mappings for new system
            sideQuest = {r = 1, g = 0.85, b = 0.3}, -- Map sideQuest to quest color
            headerBg = {r = 0, g = 0, b = 0, a = 0},
            separator = {r = 0, g = 0, b = 0, a = 0}, -- Hidden
            indentLine = {r = 0, g = 0, b = 0, a = 0} -- Hidden
        },
        
        icons = {
            -- Empty to disable icons by default
        },
        
        animations = {
            fadeInDuration = 0.4,
            slideX = 20,
        }
    }
}

-- Current active theme alias
AQT.ASSETS = AQT.Themes.Default

function AQT:UpdateTheme()
    -- Placeholder for dynamic theme switching
    self.ASSETS = self.Themes.Default
end
