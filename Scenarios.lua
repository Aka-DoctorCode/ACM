-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Scenarios.lua
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

function AQT:RenderScenario(startY, lineIdx, barIdx, style)
    local ASSETS = ns.ASSETS or AQT.ASSETS or {}
    local s = style or { headerSize = 14, textSize = 12, barHeight = 10, lineSpacing = 6 }
    local padding = ASSETS.padding or 10
    local yOffset = startY
    local width = self.db.profile.width or 260
    local db = self.db.profile

    -- Secure Font Loading Logic
    local font = ASSETS.font
    if not font and GameFontNormal then
        local fontPath, _, _ = GameFontNormal:GetFont()
        font = fontPath
    end
    
    -- Hard fallback if dynamic loading fails
    if not font or type(font) ~= "string" then
        font = "Fonts\\FRIZQT__.TTF"
    end
    
    -- Check for Test Mode OR Actual Scenario
    local inScenario = (C_Scenario and C_Scenario.IsInScenario())
    if not db.testMode and not inScenario then return yOffset, lineIdx, barIdx end

    ----------------------------------------------------------------------------
    -- A. CHALLENGE MODE (M+) TIMER
    ----------------------------------------------------------------------------
    local hasTimer = false
    local level, timeLimit, timeRem = 0, 0, 0
    
    if db.testMode then
        hasTimer = true
        level = 15
        timeLimit = 1800
        timeRem = 450 -- Low time test
    elseif C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
        local timerID = C_ChallengeMode.GetActiveChallengeMapID()
        if timerID then
            hasTimer = true
            level = C_ChallengeMode.GetActiveKeystoneInfo()
            local _, _, limit = C_ChallengeMode.GetMapUIInfo(timerID)
            local _, elapsedTime = GetWorldElapsedTime(1)
            timeLimit = limit or 0
            timeRem = (timeLimit) - (elapsedTime or 0)
        end
    end

    if hasTimer then
        -- Keystone Header
        local header = self:GetLine(lineIdx)
        header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        local hSz = s.headerSize or s.titleSize or 14
        header.text:SetFont(font, hSz + 2, "OUTLINE")
        
        local cHead = ASSETS.colors.header or {r=1, g=1, b=1}
        header.text:SetTextColor(cHead.r, cHead.g, cHead.b)
        self.SafelySetText(header.text, string.format("+%d Keystone", level or 0))
        header:Show()
        yOffset = yOffset - (hSz + 4); lineIdx = lineIdx + 1

        -- Timer Text
        local timerLine = self:GetLine(lineIdx)
        timerLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        timerLine.text:SetFont(font, 18, "OUTLINE") 
        self.SafelySetText(timerLine.text, self:FormatTime(timeRem))
        
        -- Color Logic (Red if low, White otherwise)
        if timeRem < 60 then
            timerLine.text:SetTextColor(1, 0.2, 0.2) 
        else
            timerLine.text:SetTextColor(1, 1, 1)
        end
        timerLine:Show()
        yOffset = yOffset - 22; lineIdx = lineIdx + 1

        -- Timer Bar
        local timeBar = self:GetBar(barIdx)
        timeBar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        timeBar:SetSize(width - 20, 6)
        timeBar:SetMinMaxValues(0, timeLimit or 1)
        timeBar:SetValue(timeLimit - timeRem)
        
        if timeRem < 60 then
            timeBar:SetStatusBarColor(1, 0.2, 0.2)
        else
            timeBar:SetStatusBarColor(1, 1, 1)
        end
        timeBar:Show()
        yOffset = yOffset - 12; barIdx = barIdx + 1
    end
    
    ----------------------------------------------------------------------------
    -- B. SCENARIO OBJECTIVES
    ----------------------------------------------------------------------------
    -- Fake Data for Test Mode
    local name, stageName, stageDesc, weightedProgress, numCriteria
    
    if db.testMode then
        name = "Test Dungeon: The Deep Run"
        stageName = "Stage 2: Clear the Tunnel"
        stageDesc = "Defeat the troggs blocking the path."
        weightedProgress = 45
        numCriteria = 0
    elseif C_Scenario and C_Scenario.GetInfo then
        name, _, _ = C_Scenario.GetInfo()
        if name then
            stageName, stageDesc, numCriteria, _, _, _, _, _, weightedProgress = C_Scenario.GetStepInfo()
        end
    end
        
    if name then
        -- Scenario Name
        local header = self:GetLine(lineIdx)
        header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
        header.text:SetFont(font, s.headerSize or 14, "OUTLINE")
        local cHead = ASSETS.colors.header or {r=1, g=1, b=1}
        header.text:SetTextColor(cHead.r, cHead.g, cHead.b)
        
        -- Collapse Logic
        local isCollapsed = self.db.profile.collapsed[name]
        local prefix = isCollapsed and "(+) " or "(-) "
        self.SafelySetText(header.text, prefix .. name)
        
        header:EnableMouse(true)
        header:RegisterForClicks("LeftButtonUp")
        header:SetScript("OnClick", function()
            self.db.profile.collapsed[name] = not self.db.profile.collapsed[name]
            self:FullUpdate()
        end)    
        
        header:Show()
        yOffset = yOffset - ((s.headerSize or 14) + (s.lineSpacing or 6)); lineIdx = lineIdx + 1
        
        if isCollapsed then return yOffset, lineIdx, barIdx end

        -- Stage Info
        if stageName and stageName ~= "" and stageName ~= name then
            local sLine = self:GetLine(lineIdx)
            sLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
            sLine.text:SetFont(font, s.descSize or 12, "OUTLINE")
            local cStage = ASSETS.colors.zone or {r=1, g=0.8, b=0}
            if s.titleColor and s.titleColor.r then cStage = s.titleColor end
            sLine.text:SetTextColor(cStage.r, cStage.g, cStage.b)
            self.SafelySetText(sLine.text, stageName)
            sLine:Show()
            yOffset = yOffset - ((s.descSize or 12) + (s.lineSpacing or 4)); lineIdx = lineIdx + 1
        end

        -- Weighted Progress (Bar only scenario)
        if weightedProgress and type(weightedProgress) == "number" then
            -- Text line
            local pLine = self:GetLine(lineIdx)
            pLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
            pLine.text:SetFont(font, s.objSize or 10, "OUTLINE")
            pLine.text:SetTextColor(1, 1, 1)
            self.SafelySetText(pLine.text, string.format("%s (%d%%)", stageDesc or stageName, weightedProgress))
            pLine:Show()
            yOffset = yOffset - ((s.objSize or 10) + 4); lineIdx = lineIdx + 1
            
            -- Bar line
            local bar = self:GetBar(barIdx)
            bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
            bar:SetSize(width - 20, s.barHeight or 10)
            bar:SetMinMaxValues(0, 100)
            bar:SetValue(weightedProgress)
            
            local cBar = ASSETS.colors.quest or {r=1, g=0.8, b=0}
            if s.barColor and s.barColor.r then cBar = s.barColor end
            
            bar:SetStatusBarColor(cBar.r, cBar.g, cBar.b, cBar.a or 1)
            bar:Show()
            yOffset = yOffset - ((s.barHeight or 10) + (s.lineSpacing or 6)); barIdx = barIdx + 1
        else
            -- Individual Criteria
            local cnt = numCriteria or 0
            if db.testMode then cnt = 2 end -- Fake criteria count

            for i = 1, cnt do
                local criteriaString, completed, quantity, totalQuantity, isWeightedProgress
                
                if db.testMode then
                    criteriaString = (i==1) and "Rescue Villagers" or "Slay the Warlord"
                    completed = (i==1)
                    quantity = (i==1) and 5 or 0
                    totalQuantity = (i==1) and 5 or 1
                    isWeightedProgress = false
                else
                    -- Robust API Call (Modern/Legacy)
                    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
                        local info = C_ScenarioInfo.GetCriteriaInfo(i)
                        if info then
                            criteriaString, completed, quantity, totalQuantity, isWeightedProgress = info.description, info.completed, info.quantity, info.totalQuantity, info.isWeightedProgress
                        end
                    elseif C_Scenario.GetCriteriaInfo then
                        local status, res = pcall(C_Scenario.GetCriteriaInfo, i)
                        if status then
                            if type(res) == "table" then
                                criteriaString, completed, quantity, totalQuantity, isWeightedProgress = res.description, res.completed, res.quantity, res.totalQuantity, res.isWeightedProgress
                            else
                                criteriaString, _, completed, quantity, totalQuantity, _, _, _, _, _, _, _, isWeightedProgress = C_Scenario.GetCriteriaInfo(i)
                            end
                        end
                    end
                end
                
                if criteriaString and criteriaString ~= "" then
                    local line = self:GetLine(lineIdx)
                    line:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                    line.text:SetFont(font, s.textSize or 12, "OUTLINE")
                    
                    local text = "- " .. criteriaString
                    if totalQuantity and totalQuantity > 0 then text = string.format("- %s: %d/%d", criteriaString, quantity, totalQuantity) end
                    if isWeightedProgress then text = string.format("- %s: %d%%", criteriaString, quantity) end
                    
                    if completed then
                        local cComp = ASSETS.colors.complete or {r=0.2, g=1, b=0.2}
                        line.text:SetTextColor(cComp.r, cComp.g, cComp.b)
                    else
                        line.text:SetTextColor(1, 1, 1)
                    end
                    self.SafelySetText(line.text, text)
                    line:Show()
                    
                    local showBar = false
                    local barMax = totalQuantity
                    local barVal = quantity
                    if not completed and (isWeightedProgress or (totalQuantity and totalQuantity > 1)) then
                        showBar = true
                        if isWeightedProgress then barMax = 100 end
                    end

                    if showBar then
                        yOffset = yOffset - ((s.textSize or 12) + 2)
                        local bar = self:GetBar(barIdx)
                        bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -padding, yOffset)
                        bar:SetSize(width - 20, s.barHeight or 10)
                        bar:SetMinMaxValues(0, barMax)
                        bar:SetValue(barVal)
                        local cBar = ASSETS.colors.quest or {r=1, g=0.8, b=0}
                        bar:SetStatusBarColor(cBar.r, cBar.g, cBar.b)
                        bar:Show()
                        yOffset = yOffset - ((s.barHeight or 10) + (s.lineSpacing or 6)); barIdx = barIdx + 1; lineIdx = lineIdx + 1
                    else
                        yOffset = yOffset - ((s.textSize or 12) + (s.lineSpacing or 6)); lineIdx = lineIdx + 1
                    end
                end
            end
        end
    end
    yOffset = yOffset - (ASSETS.spacing or 15)
    return yOffset, lineIdx, barIdx
end