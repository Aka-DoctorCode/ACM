-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Achievements.lua
-- Version: 07
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global
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

function AQT:RenderAchievements(startY, lineIdx, style)
    local ASSETS = ns.ASSETS or AQT.ASSETS or {}
    local s = style or { headerSize = 12, textSize = 10, barHeight = 4, lineSpacing = 6 }
    local padding = ASSETS.padding or 10
    local yOffset = startY
    local db = self.db.profile
    
    -- Safe Colors
    local colors = ASSETS.colors or {}
    local cHead = colors.header or {r=1, g=1, b=1}
    local cAchBase = colors.achievement or {r=1, g=0.8, b=0}

    -- Secure Font Loading
    local font = ASSETS.font
    if not font and GameFontNormal then
        local fontPath, _, _ = GameFontNormal:GetFont()
        font = fontPath
    end
    if not font or type(font) ~= "string" then font = "Fonts\\FRIZQT__.TTF" end
    
    -- 2. Get Tracked Achievements (Fake or Real)
    local tracked = {}
    
    if db.testMode then
        tracked = { -1, -2 } -- Fake Test IDs
    elseif GetTrackedAchievements then
        local status, t1, t2, t3, t4, t5, t6, t7, t8, t9, t10 = pcall(GetTrackedAchievements)
        if status then
             if t1 then table.insert(tracked, t1) end
             if t2 then table.insert(tracked, t2) end
             if t3 then table.insert(tracked, t3) end
             if t4 then table.insert(tracked, t4) end
        end
    end
    
    if #tracked == 0 then return yOffset, lineIdx end

    -- 3. Calculate Dimensions
    local hHead = (s.headerSize or s.titleSize or 12) + (s.lineSpacing or 6)
    local width = self.db.profile.width or 260

    -- 4. Main Section Header
    local header = self:GetLine(lineIdx)
    header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
    
    header.text:SetFont(font, s.headerSize or 14, "OUTLINE")
    header.text:SetTextColor(cHead.r, cHead.g, cHead.b)
    
    local isCollapsed = self.db.profile.collapsed["ACHIEVEMENTS"]
    local prefix = isCollapsed and "(+) " or "(-) "
    -- FIX: Changed to Title Case
    self.SafelySetText(header.text, prefix .. "Achievements")
    
    header:EnableMouse(true)
    header:RegisterForClicks("LeftButtonUp")
    header:SetScript("OnClick", function()
        self.db.profile.collapsed["ACHIEVEMENTS"] = not self.db.profile.collapsed["ACHIEVEMENTS"]
        self:FullUpdate()
    end)
    
    header:Show()
    
    yOffset = yOffset - (hHead + 4)
    lineIdx = lineIdx + 1
    
    if isCollapsed then return yOffset, lineIdx end

    -- 5. Render Each Achievement
    for i = 1, #tracked do
        local achID = tracked[i]
        
        -- VALIDATE ID
        if achID then
            local id, name, completed, description, icon
            
            if db.testMode then
                id = achID
                name = (achID == -1) and "Test: Gladiator" or "Test: Master Angler"
                completed = false
            else
                -- Verify ID exists
                id, name, _, completed, _, _, _, _, _, icon = GetAchievementInfo(achID)
            end
            
            if id and not completed then
                -- Achievement Title
                local line = self:GetLine(lineIdx)
                line:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                
                line.text:SetFont(font, s.titleSize or 14, "OUTLINE")
                
                local cAch = cAchBase
                if s.titleColor and s.titleColor.r then cAch = s.titleColor end
                
                line.text:SetTextColor(cAch.r, cAch.g, cAch.b, cAch.a or 1)
                
                self.SafelySetText(line.text, name)
                line:Show()
                
                -- Interaction
                line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                line:SetScript("OnClick", function(self, button)
                    if db.testMode then return end
                    if button == "RightButton" then
                        if RemoveTrackedAchievement then 
                            RemoveTrackedAchievement(achID) 
                            if AQT.FullUpdate then AQT:FullUpdate() end
                        end
                    else
                        if not AchievementFrame then AchievementFrame_LoadUI() end
                        if AchievementFrame_SelectAchievement then
                            AchievementFrame_SelectAchievement(achID)
                        end
                    end
                end)
                
                -- Tooltip
                line:SetScript("OnEnter", function(self)
                    if db.testMode then return end
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:SetAchievementByID(achID)
                    GameTooltip:Show()
                end)
                line:SetScript("OnLeave", function() GameTooltip:Hide() end)
                
                yOffset = yOffset - ((s.titleSize or 14) + (s.lineSpacing or 4))
                lineIdx = lineIdx + 1
                
                -- Criteria
                local numCriteria = 0
                if db.testMode then
                    numCriteria = 2
                else
                    numCriteria = GetAchievementNumCriteria(achID)
                end

                for j = 1, numCriteria do
                    local cName, cType, cComp, cQty, cReq, cQtyString
                    local isHidden = false
                    
                    if db.testMode then
                        cName = (j == 1) and "Objective A" or "Objective B"
                        cComp = (j == 1)
                        cQty = (j == 1) and 1 or 5
                        cReq = 10
                        cQtyString = (j == 2) and "5/10" or "1/10"
                    else
                        local _
                        cName, cType, cComp, cQty, cReq, _, _, _, cQtyString, _ = GetAchievementCriteriaInfo(achID, j)
                        if not cName or cName == "" then isHidden = true end
                    end
                    
                    if not cComp and not isHidden and cName and cName ~= "" then 
                        local cLine = self:GetLine(lineIdx)
                        cLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                        
                        cLine.text:SetFont(font, s.objSize or 10, "OUTLINE")
                        cLine.text:SetTextColor(0.8, 0.8, 0.8) 
                        
                        local cText = "- " .. cName
                        if cQtyString and cQtyString ~= "" then
                            cText = string.format("- %s: %s", cName, cQtyString)
                        elseif cReq and cReq > 1 then 
                            cText = string.format("- %s: %d/%d", cName, cQty or 0, cReq) 
                        end
                        
                        self.SafelySetText(cLine.text, cText)
                        cLine:Show()
                        
                        yOffset = yOffset - ((s.objSize or 10) + 2)
                        lineIdx = lineIdx + 1
                    end
                end
                
                yOffset = yOffset - 6 
            end
        end
    end
    
    yOffset = yOffset - (ASSETS.spacing or 10)

    return yOffset, lineIdx
end