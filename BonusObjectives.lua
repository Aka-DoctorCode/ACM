-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: BonusObjectives.lua
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

-- Renders the progress bar for Bonus Objectives and World Quests
function AQT:RenderBonusObjectiveBar(qID, lineIdx, barIdx, width, yOffset)
    local isComplete = C_QuestLog.IsComplete(qID)

    if not isComplete and C_TaskQuest and C_TaskQuest.GetQuestProgressBarInfo then
        local progress = C_TaskQuest.GetQuestProgressBarInfo(qID)
        if progress then
            local pLine = self:GetLine(lineIdx)
            -- [FIX] Use self.Content instead of self to anchor the frame correctly
            pLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
            pLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")

            -- Protection against nil color
            -- If ASSETS.colors.wq does not exist, use a default Blue
            local color = {r=0.2, g=0.6, b=1, a=1}
            if ASSETS.colors and ASSETS.colors.wq then
                color = ASSETS.colors.wq
            end

            self.SafelySetText(pLine.text, string.format("Progress: %d%%", progress))
            pLine:Show()
            yOffset = yOffset - 12
            lineIdx = lineIdx + 1

            local bar = self:GetBar(barIdx)
            -- [FIX] Use self.Content instead of self to anchor the frame correctly
            bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
            bar:SetSize(width - 20, ASSETS.barHeight)

            -- Ensure texture (important for visibility)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

            bar:SetValue(progress / 100)
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:Show()
            yOffset = yOffset - 8
            barIdx = barIdx + 1

            return yOffset, lineIdx, barIdx, true -- Returns true to indicate a bar was rendered
        end
    end

    return yOffset, lineIdx, barIdx, false
end
