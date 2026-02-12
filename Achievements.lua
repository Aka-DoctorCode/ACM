-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Achievements.lua
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

function AQT:RenderAchievements(startY, lineIdx)
    local yOffset = startY
    local tracked = GetTrackedAchievements and { GetTrackedAchievements() } or {}
    if #tracked == 0 then return yOffset, lineIdx end

    -- Cálculos
    local hHead = ASSETS.fontHeaderSize + (ASSETS.lineSpacing or 6)
    local hText = ASSETS.fontTextSize + (ASSETS.lineSpacing or 6)

    -- Main Header
    local header = self:GetLine(lineIdx)
    header.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
    header:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, yOffset)
    header.text:SetTextColor(ASSETS.colors.header.r, ASSETS.colors.header.g, ASSETS.colors.header.b)
    
    -- Ancho dinámico
    local width = AscensionQuestTrackerDB.width or 260
    header:SetSize(width, hHead)
    
    self.SafelySetText(header.text, "  Achievements  ")
    header:Show()
    yOffset = yOffset - (hHead + 4)
    lineIdx = lineIdx + 1

    for _, achID in ipairs(tracked) do
        local id, name, _, completed = GetAchievementInfo(achID)
        if not completed and id then
            local line = self:GetLine(lineIdx)
            line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, yOffset)
            line.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE") -- Logros como headers pequeños
            line.text:SetTextColor(ASSETS.colors.achievement.r, ASSETS.colors.achievement.g, ASSETS.colors.achievement.b)
            self.SafelySetText(line.text, name)
            
            -- Interaction (Click)
            line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            line:SetScript("OnClick", function(self, button)
                if button == "RightButton" then
                     if RemoveTrackedAchievement then 
                        RemoveTrackedAchievement(achID) 
                        if AQT.FullUpdate then AQT:FullUpdate() end
                     end
                else
                     if not AchievementFrame then AchievementFrame_LoadUI() end
                     AchievementFrame_SelectAchievement(achID)
                end
            end)
            line:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetAchievementByID(achID)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            line:Show()
            yOffset = yOffset - hHead 
            lineIdx = lineIdx + 1
            
            -- Criteria
            local numCriteria = GetAchievementNumCriteria(achID)
            for i = 1, numCriteria do
                local cName, _, cComp, cQty, cReq = GetAchievementCriteriaInfo(achID, i)
                if not cComp and (bit.band(select(7, GetAchievementCriteriaInfo(achID, i)), 1) ~= 1) then
                    local cLine = self:GetLine(lineIdx)
                    cLine:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, yOffset)
                    cLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                    
                    local cText = cName
                    if cReq and cReq > 1 then cText = string.format("%s: %d/%d", cName, cQty, cReq) end
                    
                    self.SafelySetText(cLine.text, cText)
                    cLine.text:SetTextColor(0.8, 0.8, 0.8)
                    cLine:Show()
                    yOffset = yOffset - hText
                    lineIdx = lineIdx + 1
                end
            end
            yOffset = yOffset - 4
        end
    end
    return yOffset, lineIdx
end
