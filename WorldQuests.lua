-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: WorldQuests.lua
-- Version: 05
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, ns = ...
local AQT = ns.AQT
local ASSETS = ns.ASSETS

-- Helper to check if a quest is a World Quest
function AQT:IsWorldQuest(qID)
    if not C_QuestLog.IsWorldQuest then return false end
    return C_QuestLog.IsWorldQuest(qID)
end

-- Gets the time remaining in minutes for a World Quest
function AQT:GetWorldQuestTimeRemaining(qID)
    if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
        return C_TaskQuest.GetQuestTimeLeftMinutes(qID) or 0
    end
    return 0
end

-- Formats the title with the time remaining if applicable
function AQT:FormatWorldQuestTitle(title, minutes)
    if minutes > 0 and minutes < 1440 then -- Less than 24h
        -- Color code the timer?
        local timeStr = ""
        if minutes < 60 then
            timeStr = string.format("|cffff4444[%dm]|r", minutes) -- Red if < 1h
        else
            local h = math.floor(minutes / 60)
            local m = minutes % 60
            timeStr = string.format("[%d:%02dh]", h, m)
        end
        return string.format("%s %s", timeStr, title)
    end
    return title
end
