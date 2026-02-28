-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode
-- File: WorldQuests.lua
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
        local timeStr = ""
        if minutes < 60 then
            timeStr = string.format("|cffff4444[%dm]|r", minutes)
        else
            local h = math.floor(minutes / 60)
            timeStr = string.format("[%d hr]", h)
        end
        return string.format("%s %s", timeStr, title)
    end
    return title
end

--------------------------------------------------------------------------------
-- RENDER WORLD QUESTS
--------------------------------------------------------------------------------
function AQT:RenderWorldQuests(startY, lineIdx, barIdx, itemIdx, style)
    -- 1. Setup Style & Assets
    local s = style or { headerSize = 12, textSize = 10, barHeight = 4, lineSpacing = 6 }
    local ASSETS = ns.ASSETS or AQT.ASSETS or {}
    local padding = ASSETS.padding or 10
    local db = self.db.profile

    -- Safe Colors
    local colors = ASSETS.colors or {}
    local cHead = colors.header or { r = 1, g = 1, b = 1 }
    local cTitleBase = colors.wq or { r = 0.6, g = 0.8, b = 1 }

    -- Secure Font Loading
    local font = ASSETS.font
    if not font and GameFontNormal then
        local fontPath, _, _ = GameFontNormal:GetFont()
        font = fontPath
    end
    if not font or type(font) ~= "string" then font = "Fonts\\FRIZQT__.TTF" end

    local y = startY

    -- Check Super Track
    local superID = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()) or 0

    -- 2. GATHER DATA (Exclusive: Manual Track OR Active In Zone)
    local wqList = {}
    local seen = {} -- Prevent duplicates

    if db.testMode then
        table.insert(wqList, -100); seen[-100] = true
        table.insert(wqList, -101); seen[-101] = true
    else
        -- A. Super Track / Focus (Always Show)
        if superID > 0 and self:IsWorldQuest(superID) and not seen[superID] then
            table.insert(wqList, superID)
            seen[superID] = true
        end

        -- B. Manually Tracked (Always show, regardless of zone)
        local numEntries = C_QuestLog.GetNumQuestWatches()
        for i = 1, numEntries do
            local qID = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if qID and self:IsWorldQuest(qID) and not seen[qID] then
                table.insert(wqList, qID)
                seen[qID] = true
            end
        end

        -- C. In The Zone (Show if Active/OnQuest)
        local currentMapID = C_Map.GetBestMapForUnit("player")
        if currentMapID and C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
            local tasks = C_TaskQuest.GetQuestsOnMap(currentMapID)
            if tasks then
                for _, taskInfo in ipairs(tasks) do
                    local qID = taskInfo.questID
                    if not seen[qID] and self:IsWorldQuest(qID) then
                        -- Check if the player is actively "On" the quest (e.g. entered area)
                        if C_QuestLog.IsOnQuest(qID) then
                            table.insert(wqList, qID)
                            seen[qID] = true
                        end
                    end
                end
            end
        end
    end

    if #wqList == 0 then return y, lineIdx, barIdx, itemIdx end

    -- 3. Render Header
    local h = self:GetLine(lineIdx)
    h:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
    h.text:SetFont(font, s.titleSize or 14, "OUTLINE")
    h.text:SetTextColor(cHead.r, cHead.g, cHead.b)

    local isCollapsed = self.db.profile.collapsed["World Quests"]
    local prefix = isCollapsed and "(+) " or "(-) "
    self.SafelySetText(h.text, prefix .. "World Quests")

    h:EnableMouse(true)
    h:RegisterForClicks("LeftButtonUp")
    h:SetScript("OnClick", function()
        self.db.profile.collapsed["World Quests"] = not self.db.profile.collapsed["World Quests"]
        self:FullUpdate()
    end)

    h:Show()

    local headSz = s.headerSize or s.titleSize or 12
    y = y - (headSz + (s.lineSpacing or 6))
    lineIdx = lineIdx + 1

    if isCollapsed then return y, lineIdx, barIdx, itemIdx end

    -- 4. Render Items
    for _, qID in ipairs(wqList) do
        local isSuperTracked = (qID == superID)
        local isTest = (qID < 0)

        -- Get Info
        local title, minutes
        if isTest then
            title = (qID == -100) and "Test: Rare Elite" or "Test: Pet Battle"
            minutes = (qID == -100) and 45 or 125
        else
            title = C_QuestLog.GetTitleForQuestID(qID)
            minutes = self:GetWorldQuestTimeRemaining(qID)
        end

        title = self:FormatWorldQuestTitle(title, minutes)

        -- Determine Colors
        local cTitle = cTitleBase
        local cBar = cTitleBase

        if s.titleColor and s.titleColor.r then cTitle = s.titleColor end
        if s.barColor and s.barColor.r then cBar = s.barColor end

        if isSuperTracked then
            if self.db.profile.focused.titleColor then cTitle = self.db.profile.focused.titleColor end
            if self.db.profile.focused.barColor then cBar = self.db.profile.focused.barColor end
        end

        -- Render Title
        local l = self:GetLine(lineIdx)
        l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
        l.text:SetFont(font, s.titleSize or 14, "OUTLINE")
        l.text:SetTextColor(cTitle.r, cTitle.g, cTitle.b, cTitle.a or 1)
        self.SafelySetText(l.text, title)
        l:Show()

        -- Click Logic
        l:SetScript("OnClick", function(self, button)
            if isTest then return end
            if button == "RightButton" then
                C_QuestLog.RemoveQuestWatch(qID)
                if AQT.FullUpdate then AQT:FullUpdate() end
            else
                if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(qID) end
            end
        end)

        y = y - ((s.titleSize or 14) + (s.lineSpacing or 4))
        lineIdx = lineIdx + 1

        -- Render Objectives
        if isTest then
            -- Mock Objectives
            local lObj = self:GetLine(lineIdx)
            lObj:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
            lObj.text:SetFont(font, s.objSize or 10)
            lObj.text:SetTextColor(0.8, 0.8, 0.8)
            self.SafelySetText(lObj.text, "- Defeat the Threat")
            lObj:Show()
            y = y - ((s.objSize or 10) + 2)
            lineIdx = lineIdx + 1
        else
            local objectives = C_QuestLog.GetQuestObjectives(qID)
            if objectives then
                for _, obj in pairs(objectives) do
                    if obj.text and obj.text ~= "" then
                        local lObj = self:GetLine(lineIdx)
                        lObj:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
                        lObj.text:SetFont(font, s.objSize or 10)
                        lObj.text:SetTextColor(0.8, 0.8, 0.8)
                        self.SafelySetText(lObj.text, "- " .. obj.text)
                        lObj:Show()
                        y = y - ((s.objSize or 10) + 2)
                        lineIdx = lineIdx + 1
                    end
                end
            end
        end

        -- Render Bar
        local pct = 0
        if isTest then
            pct = 65
        elseif C_TaskQuest and C_TaskQuest.GetQuestProgressBarInfo then
            pct = C_TaskQuest.GetQuestProgressBarInfo(qID)
        end

        if pct and pct > 0 then
            local b = self:GetBar(barIdx)
            b:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, y)
            b:SetSize((self.db.profile.width or 260) - 40, s.barHeight or 10)
            b:SetMinMaxValues(0, 100)
            b:SetValue(pct)
            b:SetStatusBarColor(cBar.r, cBar.g, cBar.b, cBar.a or 1)
            b:Show()
            y = y - ((s.barHeight or 10) + (s.lineSpacing or 4))
            barIdx = barIdx + 1
        end

        y = y - 4
    end

    y = y - (ASSETS.spacing or 10)
    return y, lineIdx, barIdx, itemIdx
end
