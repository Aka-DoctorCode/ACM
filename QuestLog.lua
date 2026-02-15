-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: QuestLog.lua
-- Version: 07
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, ns = ...
local AQT = ns.AQT
if not AQT then 
    ns.AQT = {}
    AQT = ns.AQT
end

-- MEMORY POOLING
-- Reusable tables to reduce Garbage Collection churn
local pooled_watchedIDs = {}
local pooled_campaign = {}
local pooled_grouped = {} -- Key: mapID, Value: Array of quest data
local pooled_zoneOrder = {}
local pooled_flatList = {}

function AQT:RenderQuests(startY, lineIdx, barIdx, itemIdx, style)
    local ASSETS = ns.ASSETS or AQT.ASSETS or {}
    local s = style or { headerSize = 13, textSize = 10, barHeight = 4, lineSpacing = 6 }
    
    -- Secure Font Loading Logic
    local font = ASSETS.font
    if not font and GameFontNormal then
        local fontPath, _, _ = GameFontNormal:GetFont()
        font = fontPath
    end
    if not font or type(font) ~= "string" then font = "Fonts\\FRIZQT__.TTF" end    
    
    local db = self.db.profile
    local yOffset = startY
    
    -- Define variables needed by RenderSection
    local hHead = (s.headerSize or s.titleSize or 13) + (s.lineSpacing or 6)
    local width = db.width or 260

    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then return yOffset, lineIdx, barIdx, itemIdx end

    ----------------------------------------------------------------------------
    -- 1. CLEANUP POOLS
    ----------------------------------------------------------------------------
    table.wipe(pooled_watchedIDs)
    table.wipe(pooled_campaign)
    table.wipe(pooled_zoneOrder)
    table.wipe(pooled_flatList)
    
    for k, v in pairs(pooled_grouped) do table.wipe(v) end

    ----------------------------------------------------------------------------
    -- 2. DATA GATHERING (EXCLUSIVE)
    ----------------------------------------------------------------------------
    if not db.testMode then
        -- A. Gather Watched Quests
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local id = C_QuestLog.GetQuestIDForQuestWatchIndex(i)
            if id then pooled_watchedIDs[id] = true end
        end

        -- B. Force Tracked Quests
        if self.ForceTrackedQuests then
            for qID, _ in pairs(self.ForceTrackedQuests) do
                if C_QuestLog.IsOnQuest(qID) then pooled_watchedIDs[qID] = true end
            end
        end
        
        -- C. Include Super Tracked Quest (Focus)
        -- This ensures the focused quest is always visible even if not "watched"
        local superID = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()) or 0
        if superID > 0 and C_QuestLog.IsOnQuest(superID) then
            pooled_watchedIDs[superID] = true
        end

        -- D. Auto-Add Zone Tasks
        local currentMapID = C_Map.GetBestMapForUnit("player")
        if currentMapID and C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
            local tasks = C_TaskQuest.GetQuestsOnMap(currentMapID)
            if tasks then
                for _, taskInfo in ipairs(tasks) do
                    pooled_watchedIDs[taskInfo.questID] = true
                end
            end
        end

        -- PROCESS REAL DATA
        for qID, _ in pairs(pooled_watchedIDs) do
            -- Skip WQs (Handled by WorldQuests module)
            local isWQ = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(qID)
            
            if not isWQ then
                local info = nil
                local logIdx = C_QuestLog.GetLogIndexForQuestID(qID)
                
                if logIdx then info = C_QuestLog.GetInfo(logIdx)
                else 
                    local title = C_QuestLog.GetTitleForQuestID(qID)
                    if title then info = { title = title, questID = qID, isHidden = false, campaignID = 0, mapID = 0 } end
                end
        
                if info and not info.isHidden then
                    -- Distance Calculation
                    local distSq = C_QuestLog.GetDistanceSqToQuest(qID)
                    local distance = distSq and math.sqrt(distSq) or 99999
                    
                    local data = { id = qID, info = info, logIdx = logIdx, distance = distance }
        
                    if info.campaignID and info.campaignID > 0 then
                        table.insert(pooled_campaign, data)
                    else
                        if db.showAllZoneHeaders then
                            -- Group by Zone
                            local mapID = info.mapID or 0
                            if not pooled_grouped[mapID] then
                                pooled_grouped[mapID] = {}
                                table.insert(pooled_zoneOrder, mapID)
                            elseif #pooled_grouped[mapID] == 0 then
                                local found = false
                                for _, m in ipairs(pooled_zoneOrder) do if m == mapID then found = true break end end
                                if not found then table.insert(pooled_zoneOrder, mapID) end
                            end
                            table.insert(pooled_grouped[mapID], data)
                        else
                            -- Flat List
                            table.insert(pooled_flatList, data)
                        end
                    end
                end
            end
        end

    else
        ----------------------------------------------------------------------------
        -- 3. TEST MODE INJECTION (EXCLUSIVE)
        ----------------------------------------------------------------------------
        local fakeQuests = {
            { id = 999901, title = "Test Campaign: Assault on Citadel", isCampaign = true, mapID = 0, dist = 50 },
            { id = 999902, title = "Test Quest: Collect 10 Apples", isCampaign = false, mapID = 2022, dist = 150 }, -- 2022 = Waking Shores
            { id = 999903, title = "Test Quest: Slay the Dragon", isCampaign = false, mapID = 2022, dist = 500 },
            { id = 999904, title = "Test Side Quest: Lost Item", isCampaign = false, mapID = 2023, dist = 1200 }, -- 2023 = Ohn'ahran Plains
        }
        
        for _, fq in ipairs(fakeQuests) do
            local info = {
                title = fq.title,
                questID = fq.id,
                campaignID = fq.isCampaign and 1 or 0,
                mapID = fq.mapID,
                isHidden = false
            }
            local data = { id = fq.id, info = info, logIdx = nil, distance = fq.dist, isTest = true }

            if fq.isCampaign then
                table.insert(pooled_campaign, data)
            elseif db.showAllZoneHeaders then
                local mapID = fq.mapID
                if not pooled_grouped[mapID] then
                    pooled_grouped[mapID] = {}
                    table.insert(pooled_zoneOrder, mapID)
                end
                table.insert(pooled_grouped[mapID], data)
            else
                table.insert(pooled_flatList, data)
            end
        end
    end

    -- Sorting Function
    local function DistanceSort(a, b) return a.distance < b.distance end

    table.sort(pooled_campaign, DistanceSort)
    
    if db.showAllZoneHeaders then
        for _, mapID in ipairs(pooled_zoneOrder) do
            table.sort(pooled_grouped[mapID], DistanceSort)
        end
    else
        table.sort(pooled_flatList, DistanceSort)
    end

    ----------------------------------------------------------------------------
    -- 4. RENDERING
    ----------------------------------------------------------------------------
    local function RenderSection(headerTitle, quests, isSubHeader)
        if #quests == 0 then return end

        -- Header
        if headerTitle then
            local hLine = self:GetLine(lineIdx)
            hLine:ClearAllPoints()
            hLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
            
            -- Font & Color
            hLine.text:SetFont(font, s.headerSize or 14, "OUTLINE")
            
            if isSubHeader then
                local c = ASSETS.colors.zone or {r=1, g=0.8, b=0}
                hLine.text:SetTextColor(c.r, c.g, c.b)
                yOffset = yOffset - hHead
            else
                local c = ASSETS.colors.header or {r=1, g=1, b=1}
                hLine.text:SetTextColor(c.r, c.g, c.b)
                yOffset = yOffset - (hHead + 4)
            end
            
            -- Collapse Logic & Text
            local isCollapsed = self.db.profile.collapsed[headerTitle]
            -- FIX: Removed string.upper() to keep natural capitalization
            local displayTitle = headerTitle 
            local prefix = isCollapsed and "(+) " or "(-) "
            
            self.SafelySetText(hLine.text, prefix .. displayTitle)
            
            hLine:EnableMouse(true)
            hLine:RegisterForClicks("LeftButtonUp")
            hLine:SetScript("OnClick", function()
                self.db.profile.collapsed[headerTitle] = not self.db.profile.collapsed[headerTitle]
                self:FullUpdate()
            end)
            
            hLine:Show(); lineIdx = lineIdx + 1
            if isCollapsed then return end
        end

        for _, qData in ipairs(quests) do
            local qID = qData.id
            local info = qData.info
            local dist = qData.distance
            local isComplete = false
            if not qData.isTest then
                isComplete = C_QuestLog.IsComplete(qID)
            end
            local isCampaign = info.campaignID and info.campaignID > 0
            
            -- Check Super Track
            local superID = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()) or 0
            local isSuperTracked = (qID == superID)

            local l = self:GetLine(lineIdx)
            l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

            -- Icon (Minimalistic Toggle Circle)
            if l.icon then
                l.icon:Show()
                local iconTexture = "Interface\\Buttons\\UI-RadioButton-UnCheck"
                if isSuperTracked then
                    iconTexture = "Interface\\Buttons\\UI-RadioButton-Check"
                end
                l.icon:SetTexture(iconTexture)

                -- Color Logic (Status Indicators)
                if isComplete then
                    l.icon:SetVertexColor(0, 1, 0) -- Green for Ready
                elseif isCampaign then
                    l.icon:SetVertexColor(0.2, 0.8, 1) -- Light Blue for Campaign
                elseif isSuperTracked then
                    l.icon:SetVertexColor(1, 0.8, 0) -- Gold for Active Focus
                else
                    l.icon:SetVertexColor(0.5, 0.5, 0.5) -- Grey for Standard
                end
                
                -- Adjust size for the radio button texture
                l.icon:SetSize((s.titleSize or 14), (s.titleSize or 14))
            end

            -- Color Selection
            local color = ASSETS.colors.quest or {r=1, g=1, b=1}
            
            -- Module Override (if defined and not nil)
            if s.titleColor and s.titleColor.r then 
                color = s.titleColor 
            end
            
            if isCampaign then 
                color = ASSETS.colors.campaign or color 
            end
            
            if isComplete then 
                color = ASSETS.colors.complete or {r=0, g=1, b=0} 
            end
            
            if isSuperTracked and self.db.profile.focused.titleColor then
                color = self.db.profile.focused.titleColor
            end

            l.text:SetTextColor(color.r, color.g, color.b)
            l.text:SetFont(font, math.max(8, s.titleSize or 14), "OUTLINE")

            -- Title + Yardage
            local titleText = info.title
            if dist and dist < 1000 then
                titleText = string.format("|cffaaaaaa[%dyd]|r %s", math.floor(dist), titleText)
            end
            if isComplete then titleText = titleText .. " |cff00ff00(Ready)|r" end
            
            self.SafelySetText(l.text, "  " .. titleText)
            l:Show()

            -- Item Button
            if not InCombatLockdown() and not qData.isTest then
                local itemLink, itemIcon, itemCount, showItemWhenComplete
                if qData.logIdx and C_QuestLog.GetQuestLogSpecialItemInfo then
                    itemLink, itemIcon, itemCount, showItemWhenComplete = C_QuestLog.GetQuestLogSpecialItemInfo(qData.logIdx)
                end

                if itemIcon and (not isComplete or showItemWhenComplete) then
                    local iBtn = self:GetItemButton(itemIdx)
                    local textWidth = l.text:GetStringWidth()
                    iBtn:ClearAllPoints()
                    iBtn:SetPoint("RIGHT", l, "RIGHT", -textWidth - 10, 0)
                    iBtn.icon:SetTexture(itemIcon)
                    iBtn.count:SetText(itemCount and itemCount > 1 and itemCount or "")
                    
                    -- Secure Attributes
                    iBtn:SetAttribute("type", nil) 
                    iBtn.itemLink = itemLink
                    iBtn:SetAttribute("type", "item")
                    iBtn:SetAttribute("item", itemLink)
                    iBtn:SetAttribute("questLogIndex", qData.logIdx)
                    
                    iBtn:SetFrameLevel(l:GetFrameLevel() + 5)
                    iBtn:Show()
                    itemIdx = itemIdx + 1
                end
            end

            -- Interaction (Safe Tooltips & Modern Context Menu)
            l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            l:SetScript("OnClick", function(self, button)
                if qData.isTest then return end -- No interaction for test quests

                if button == "LeftButton" then
                    if IsShiftKeyDown() then
                        local link = C_QuestLog.GetQuestLink(qID)
                        if link then ChatEdit_InsertLink(link) end
                    else
                        if QuestMapFrame_OpenToQuestDetails then 
                            QuestMapFrame_OpenToQuestDetails(qID) 
                        elseif C_QuestLog.OpenQuestLog then
                            C_QuestLog.OpenQuestLog(qID)
                        end
                    end
                elseif button == "LeftButton" and IsAltKeyDown() then
                    -- Toggle Focus/SuperTrack functionality
                    if isSuperTracked then
                        C_SuperTrack.ClearAllSuperTracked()
                    else
                        C_SuperTrack.SetSuperTrackedQuestID(qID)
                    end
                    AQT:FullUpdate() -- Force visual update immediately
                elseif button == "RightButton" then
                    if MenuUtil and MenuUtil.CreateContextMenu then
                        MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                            rootDescription:CreateTitle(info.title)
                            rootDescription:CreateButton("Focus / SuperTrack", function() C_SuperTrack.SetSuperTrackedQuestID(qID) end)
                            rootDescription:CreateButton("Open Map", function() QuestMapFrame_OpenToQuestDetails(qID) end)
                            if C_QuestLog.IsPushableQuest(qID) and IsInGroup() then
                                rootDescription:CreateButton("Share", function() C_QuestLog.ShareQuest(qID) end)
                            end
                            rootDescription:CreateButton("|cffff4444Abandon|r", function() QuestMapFrame_AbandonQuest(qID) end)
                            rootDescription:CreateButton("Stop Tracking", function() 
                                C_QuestLog.RemoveQuestWatch(qID) 
                                if AQT.FullUpdate then AQT:FullUpdate() end
                            end)
                        end)
                    else
                        -- Legacy Fallback
                        C_QuestLog.RemoveQuestWatch(qID)
                        if AQT.FullUpdate then AQT:FullUpdate() end
                    end
                end
            end)
            
            l:SetScript("OnEnter", function(self)
                if qData.isTest then return end
                AQT:SafeCall(function()
                    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                    GameTooltip:SetText(info.title)
                    GameTooltip:Show()
                end)
            end)
            l:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            yOffset = yOffset - (s.titleSize or 14) - 2
            lineIdx = lineIdx + 1

            -- Objectives
            if not isComplete then
                local objectives
                if qData.isTest then
                    objectives = {
                        { text = "Test Objective: 5/10", numRequired = 10, numFulfilled = 5, finished = false },
                        { text = "Test Completed Obj", numRequired = 1, numFulfilled = 1, finished = true }
                    }
                else
                    objectives = C_QuestLog.GetQuestObjectives(qID)
                end

                if objectives then
                    for _, obj in ipairs(objectives) do
                        if obj.text and not obj.finished then
                            local oLine = self:GetLine(lineIdx)
                            oLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                            oLine.text:SetFont(font, s.objSize or 10)
                            oLine.text:SetTextColor(0.7, 0.7, 0.7)
                            self.SafelySetText(oLine.text, "    " .. obj.text)
                            oLine:Show()
                            yOffset = yOffset - (s.objSize or 10) - 2
                            lineIdx = lineIdx + 1
                            if obj.numRequired and obj.numRequired > 0 then
                                local bar = self:GetBar(barIdx)
                                bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                                bar:SetSize(width - 40, s.barHeight)
                                bar:SetValue(obj.numFulfilled / obj.numRequired)
                                
                                -- Bar Color Logic
                                local barC = ASSETS.colors.sideQuest or {r=0, g=0.7, b=1}
                                if s.barColor and s.barColor.r then barC = s.barColor end
                                if isSuperTracked and self.db.profile.focused.barColor then barC = self.db.profile.focused.barColor end
                                
                                bar:SetStatusBarColor(barC.r, barC.g, barC.b)
                                bar:Show()
                                yOffset = yOffset - (s.barHeight + 4)
                                barIdx = barIdx + 1
                            end
                        end
                    end
                end
            end
            yOffset = yOffset - 2
        end
        yOffset = yOffset - (s.lineSpacing or 6)
    end

    -- 5. FINAL RENDER CALLS
    RenderSection("Campaign", pooled_campaign, false)

    if db.showAllZoneHeaders then
        for _, mapID in ipairs(pooled_zoneOrder) do
            local mapInfo = C_Map.GetMapInfo(mapID)
            local zoneName = (mapInfo and mapInfo.name) or "Test Zone"
            RenderSection(zoneName, pooled_grouped[mapID], true)
        end
    else
        if #pooled_flatList > 0 then
            RenderSection("Quests", pooled_flatList, false)
        end
    end

    return yOffset, lineIdx, barIdx, itemIdx
end