-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Core.lua
-- Version: 07
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------

local addonName, ns = ...
local AQT = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
ns.AQT = AQT

-- ----------------------------------------------------------------------------
-- DEFAULTS
-- ----------------------------------------------------------------------------
local defaults = {
    profile = {
        autoSuperTrack = true,
        hideOnBoss = true,
        hideBlizzardTracker = false,
        showAllZoneHeaders = true,
        testMode = false,
        locked = false,
        scale = 1.0,
        width = 300,
        maxHeight = 600,
        sectionSpacing = 10,
        colors = {
            header = { r = 1, g = 0.82, b = 0, a = 1 },
            zone = { r = 1, g = 1, b = 1, a = 1 },
            quest = { r = 1, g = 1, b = 1, a = 1 },
            complete = { r = 0, g = 1, b = 0, a = 1 },
            campaign = { r = 1, g = 0.5, b = 0, a = 1 },
            wq = { r = 0, g = 0.7, b = 1, a = 1 },
            achievement = { r = 1, g = 0.82, b = 0, a = 1 },
            sideQuest = { r = 0, g = 1, b = 0, a = 1 },
        },
        collapsed = {},
        focused = {
            titleColor = { r = 1, g = 1, b = 1, a = 1 },
            barColor = { r = 1, g = 0.8, b = 0, a = 1 },
        },
        styles = {
            scenarios = { 
                titleSize = 14, descSize = 12, objSize = 10, barHeight = 10, lineSpacing = 4, 
                titleColor = {r=1, g=1, b=1, a=1}, barColor = {r=0.2, g=1, b=0.2, a=1} 
            },
            quests = { 
                titleSize = 14, descSize = 12, objSize = 10, barHeight = 10, lineSpacing = 4,
                titleColor = {r=1, g=1, b=1, a=1}, barColor = {r=1, g=0.8, b=0, a=1}
            },
            worldQuests = { 
                titleSize = 14, descSize = 12, objSize = 10, barHeight = 10, lineSpacing = 4,
                titleColor = {r=0.3, g=0.7, b=1, a=1}, barColor = {r=0.3, g=0.7, b=1, a=1}
            },
            achievements = { 
                titleSize = 14, descSize = 12, objSize = 10, barHeight = 10, lineSpacing = 4,
                titleColor = {r=1, g=0.8, b=0, a=1}, barColor = {r=1, g=0.8, b=0, a=1}
            },
        },
    }
}

-- ----------------------------------------------------------------------------
-- INITIALIZATION
-- ----------------------------------------------------------------------------
function AQT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionQuestTrackerDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    self:SetupOptions()
end

function AQT:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "FullUpdate")
    self:RegisterEvent("ACHIEVEMENT_EARNED", "FullUpdate")
    self:RegisterEvent("QUEST_LOG_UPDATE", "FullUpdate")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "FullUpdate")
    self:RegisterEvent("SCENARIO_UPDATE", "FullUpdate")
    self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", "FullUpdate")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "FullUpdate")
    self:RegisterEvent("CHALLENGE_MODE_START", "FullUpdate")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "FullUpdate")
    self:RegisterEvent("CHALLENGE_MODE_RESET", "FullUpdate")
    self:FullUpdate()
end

function AQT:FullUpdate()
    if self.UpdateLayout then
        self:UpdateLayout()
    end
end

function AQT:RefreshConfig()
    self.db = self.db or LibStub("AceDB-3.0"):New("AscensionQuestTrackerDB", defaults, true)
    self:FullUpdate()
    self:UpdateBlizzardTrackerVisibility()
end

function AQT:UpdateBlizzardTrackerVisibility()
    if self.db.profile.hideBlizzardTracker then
        if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Hide() end
    else
        if ObjectiveTrackerFrame then ObjectiveTrackerFrame:Show() end
    end
end