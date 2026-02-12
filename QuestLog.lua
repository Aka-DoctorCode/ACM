-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: QuestLog.lua
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
local ASSETS = ns.ASSETS or {}

local pooled_quests = {}
local pooled_grouped = {}
local pooled_zoneOrder = {}
local pooled_watchedIDs = {}

local function GetColor(group, fallback)
    if ASSETS.colors and ASSETS.colors[group] then return ASSETS.colors[group] end
    return fallback or {r=1, g=1, b=1, a=1}
end

function AQT:GetBestQuestForSuperTracking()
    if #pooled_quests > 0 then
        local bestID, bestDist = nil, 999999
        for _, q in ipairs(pooled_quests) do
            if q.distValue and q.distValue > 0 and q.distValue < bestDist then
                bestDist = q.distValue
                bestID = q.id
            end
        end
        return bestID
    end
    return nil
end

function AQT:RenderQuests(startY, lineIdx, barIdx, itemIdx)
    local shouldHide = self.db.profile.hideOnBoss -- Ace3 DB
    if shouldHide and self.inBossCombat then return startY, lineIdx, barIdx, itemIdx end

    local hHead = ASSETS.fontHeaderSize + (ASSETS.lineSpacing or 6)
    local hText = ASSETS.fontTextSize + (ASSETS.lineSpacing or 6)
    local hSub  = (ASSETS.fontTextSize - 1) + (ASSETS.lineSpacing or 6)

    local yOffset = startY
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then return yOffset, lineIdx, barIdx, itemIdx end

    local width = self.db.profile.width or 260

    -- DATA GATHERING (Sin cambios en lógica, solo estructura)
    local campaignQuests = {}
    local worldQuests = {}
    local sideQuests = {}
    local sideQuestsZoneOrder = {}

    table.wipe(pooled_watchedIDs)
    table.wipe(pooled_quests)

    if C_QuestLog.GetQuestIDForWatch then
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local id = C_QuestLog.GetQuestIDForWatch(i)
            if id then table.insert(pooled_watchedIDs, id) end
        end
    end

    local currentMapID = C_Map.GetBestMapForUnit("player")
    if currentMapID and C_TaskQuest and C_TaskQuest.GetQuestsOnMap then
        local tasks = C_TaskQuest.GetQuestsOnMap(currentMapID)
        if tasks then
            for _, taskInfo in ipairs(tasks) do
                local qID = taskInfo.questID
                local exists = false
                for _, v in ipairs(pooled_watchedIDs) do if v == qID then exists = true; break end end
                if not exists then table.insert(pooled_watchedIDs, qID) end
            end
        end
    end

    if C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                 local isWQ = C_QuestLog.IsWorldQuest(info.questID)
                 if self.IsWorldQuest then isWQ = isWQ or self:IsWorldQuest(info.questID) end
                 local isWatched = C_QuestLog.GetQuestWatchType(info.questID) ~= nil
                 if isWatched or isWQ then
                      local exists = false
                      for _, v in ipairs(pooled_watchedIDs) do if v == info.questID then exists = true; break end end
                      if not exists then table.insert(pooled_watchedIDs, info.questID) end
                 end
            end
        end
    end

    for _, qID in ipairs(pooled_watchedIDs) do
        local info = nil
        local logIdx = C_QuestLog.GetLogIndexForQuestID(qID)

        if logIdx then
            info = C_QuestLog.GetInfo(logIdx)
        else
            local title = C_QuestLog.GetTitleForQuestID(qID)
            if title and title ~= "" then
                info = { title = title, questID = qID, isHeader = false, isHidden = false, campaignID = 0, mapID = 0 }
                if C_TaskQuest and C_TaskQuest.GetQuestZoneID then info.mapID = C_TaskQuest.GetQuestZoneID(qID) or 0 end
            end
        end

        local isWQ = C_QuestLog.IsWorldQuest(qID) or C_QuestLog.IsQuestTask(qID)
        if self.IsWorldQuest then isWQ = isWQ or self:IsWorldQuest(qID) end

        if info and (not info.isHidden or isWQ) then
            local isCampaign = info.campaignID and info.campaignID > 0
            local data = { id = qID, info = info, timeRem = 0 }

            local distSq = C_QuestLog.GetDistanceSqToQuest(qID)
            data.distValue = (distSq and distSq >= 0) and distSq or 999999
            table.insert(pooled_quests, data)

            if self.GetWorldQuestTimeRemaining then data.timeRem = self:GetWorldQuestTimeRemaining(qID) end

            if isCampaign then
                table.insert(campaignQuests, data)
            elseif isWQ then
                table.insert(worldQuests, data)
            else
                local mapID = info.mapID or 0
                if not sideQuests[mapID] then
                    sideQuests[mapID] = {}
                    table.insert(sideQuestsZoneOrder, mapID)
                end
                table.insert(sideQuests[mapID], data)
            end
        end
    end

    -- RENDER LOGIC
    local function RenderSection(headerTitle, headerIconAtlas, quests, isSubHeader)
        if #quests == 0 then return end

        if headerTitle then
            local hLine = self:GetLine(lineIdx)
            -- [FIX] Usar self.Content en lugar de self
            hLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

            hLine.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
            local cHead = GetColor("header", {r=1, g=1, b=1})
            hLine.text:SetTextColor(cHead.r, cHead.g, cHead.b)

            if headerIconAtlas and hLine.icon then
                hLine.icon:Show()
                hLine.icon:SetAtlas(headerIconAtlas)
                hLine.icon:SetSize(ASSETS.fontHeaderSize + 2, ASSETS.fontHeaderSize + 2)
            end

            if isSubHeader then
                 local cZone = GetColor("zone", {r=1, g=0.8, b=0})
                 hLine.text:SetTextColor(cZone.r, cZone.g, cZone.b)
                 self.SafelySetText(hLine.text, "  " .. headerTitle)
                 yOffset = yOffset - hHead
            else
                 self.SafelySetText(hLine.text, "  " .. string.upper(headerTitle))
                 if hLine.separator then hLine.separator:Show() end
                 yOffset = yOffset - (hHead + 4)
            end

            hLine:Show()
            lineIdx = lineIdx + 1
        end

        for _, qData in ipairs(quests) do
            local qID = qData.id
            local info = qData.info
            local isComplete = C_QuestLog.IsComplete(qID)

            local l = self:GetLine(lineIdx)
            -- [FIX] Usar self.Content
            l:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

            if l.icon then
                l.icon:Show()
                if isComplete then
                    if ASSETS.icons and ASSETS.icons.check then l.icon:SetAtlas(ASSETS.icons.check)
                    else l.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready") end
                    l.icon:SetVertexColor(0.2, 1, 0.2)
                else
                    if ASSETS.icons and ASSETS.icons.wq and C_QuestLog.IsWorldQuest(qID) then l.icon:SetAtlas(ASSETS.icons.wq)
                    elseif ASSETS.icons and ASSETS.icons.side then l.icon:SetAtlas(ASSETS.icons.side)
                    else l.icon:SetTexture("Interface\\Buttons\\UI-MicroButton-Quest-Up") end
                    l.icon:SetVertexColor(1, 1, 1)
                end
                l.icon:SetSize(ASSETS.fontTextSize + 4, ASSETS.fontTextSize + 4)
            end

            local color = GetColor("quest", {r=1, g=1, b=1})
            if isComplete then color = GetColor("complete", {r=0, g=1, b=0}) end

            l.text:SetTextColor(color.r, color.g, color.b)
            l.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")

            -- 1. Determine Title Text
            local titleText = info.title
            if isComplete then titleText = titleText .. " |cff00ff00(Ready)|r" end
            self.SafelySetText(l.text, "  " .. titleText)
            l:Show()

            -- 2. Quest Item Button Logic
            -- Only render if not in combat (Secure frames cannot be moved/shown in combat)
            if not InCombatLockdown() then
                local itemLink, itemIcon, itemCount, showItemWhenComplete
                
                -- We need the log index to get item info
                if logIdx then
                    itemLink, itemIcon, itemCount, showItemWhenComplete = GetQuestLogSpecialItemInfo(logIdx)
                end

                if itemIcon and (not isComplete or showItemWhenComplete) then
                    local iBtn = self:GetItemButton(itemIdx)
                    
                    -- Calculate position: to the left of the text, or to the right of the tracker? 
                    -- Reborn style: Right aligned, shifting left based on text width
                    local textWidth = l.text:GetStringWidth()
                    -- Adjust "20" based on your padding preferences
                    local basePointX = -ASSETS.padding - textWidth - 15 
                    
                    -- Position the button next to the title
                    iBtn:ClearAllPoints()
                    iBtn:SetPoint("RIGHT", l, "RIGHT", -textWidth - 10, 0)
                    
                    -- Visuals
                    iBtn.icon:SetTexture(itemIcon)
                    iBtn.icon:SetVertexColor(1, 1, 1)
                    iBtn.count:SetText(itemCount and itemCount > 1 and itemCount or "")
                    
                    -- Secure Attributes (The Magic)
                    -- Reset first to avoid taint issues
                    iBtn:SetAttribute("type", nil)
                    iBtn:SetAttribute("item", nil)
                    iBtn:SetAttribute("questLogIndex", nil)

                    iBtn.itemLink = itemLink -- Saved for Shift-Click hook
                    iBtn:SetAttribute("type", "item")
                    iBtn:SetAttribute("item", itemLink)
                    iBtn:SetAttribute("questLogIndex", logIdx)
                    
                    -- Ensure it's above the background
                    iBtn:SetFrameLevel(l:GetFrameLevel() + 5)
                    iBtn:Show()
                    
                    itemIdx = itemIdx + 1
                end
            end

            l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            l:SetScript("OnClick", function(self, button)
                -- 1. Left Click: Open Map / Details
                if button == "LeftButton" then
                    if IsShiftKeyDown() then
                        -- Chat Link
                        local link = GetQuestLink(qID)
                        if link then ChatEdit_InsertLink(link) end
                    else
                        -- Open Map
                        if QuestMapFrame_OpenToQuestDetails then
                            QuestMapFrame_OpenToQuestDetails(qID)
                        else
                            if C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_QuestMap") end
                            if QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(qID) end
                        end
                    end
                    
                -- 2. Right Click: Context Menu
                elseif button == "RightButton" then
                    -- Detect Precise Type for Menu Options
                    local isRealWQ = false
                    if C_QuestLog.IsWorldQuest then isRealWQ = C_QuestLog.IsWorldQuest(qID) end
                    
                    local isBonus = false
                    if not isRealWQ and GetTaskInfo then
                        local isInArea = GetTaskInfo(qID)
                        if isInArea then isBonus = true end
                    end

                    -- A. Bonus Objectives (No Menu, just return)
                    if isBonus then return end

                    -- B. Modern Context Menu (MenuUtil)
                    if MenuUtil and MenuUtil.CreateContextMenu then
                        MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                            rootDescription:CreateTitle(info.title)

                            -- Option: Focus / SuperTrack
                            rootDescription:CreateButton("Focus / SuperTrack", function() 
                                C_SuperTrack.SetSuperTrackedQuestID(qID) 
                            end)

                            -- Option: Open Map
                            rootDescription:CreateButton("Open Map", function() 
                                QuestMapFrame_OpenToQuestDetails(qID) 
                            end)

                            -- Option: Share Quest
                            if C_QuestLog.IsPushableQuest(qID) and IsInGroup() then
                                rootDescription:CreateButton("Share", function() 
                                    C_QuestLog.ShareQuest(qID) 
                                end)
                            end

                            -- World Quests stop here (cannot abandon)
                            if isRealWQ then return end

                            -- Option: Abandon (Red Text)
                            rootDescription:CreateButton("|cffff4444Abandon|r", function() 
                                QuestMapFrame_AbandonQuest(qID) 
                            end)

                            -- Option: Stop Tracking
                            rootDescription:CreateButton("Stop Tracking", function() 
                                C_QuestLog.RemoveQuestWatch(qID) 
                                if AQT.FullUpdate then AQT:FullUpdate() end
                            end)
                        end)
                    else
                        -- Fallback for older clients or if MenuUtil is missing
                        C_QuestLog.RemoveQuestWatch(qID)
                        if AQT.FullUpdate then AQT:FullUpdate() end
                    end
                end
            end)
            l:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(info.title)
                GameTooltip:Show()
            end)
            l:SetScript("OnLeave", function() GameTooltip:Hide() end)

            yOffset = yOffset - hText
            lineIdx = lineIdx + 1

            if not isComplete then
                local objectives = C_QuestLog.GetQuestObjectives(qID)
                for _, obj in ipairs(objectives or {}) do
                    if obj.text and not obj.finished then
                        local oLine = self:GetLine(lineIdx)
                        -- [FIX] Usar self.Content
                        oLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)

                        if oLine.indentLine then
                            oLine.indentLine:Show()
                            oLine.indentLine:SetHeight(hSub)
                            oLine.indentLine:SetPoint("TOPLEFT", oLine, "TOPLEFT", 6, 0)
                        end

                        oLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize - 1)
                        oLine.text:SetTextColor(0.7, 0.7, 0.7)
                        self.SafelySetText(oLine.text, "    " .. obj.text)
                        oLine:Show()
                        yOffset = yOffset - hSub
                        lineIdx = lineIdx + 1

                         if obj.numRequired and obj.numRequired > 0 then
                            local bar = self:GetBar(barIdx)
                            -- [FIX] Usar self.Content
                            bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                            bar:SetSize(width - 40, ASSETS.barHeight)
                            bar:SetValue(obj.numFulfilled / obj.numRequired)
                            local cSide = GetColor("sideQuest", {r=0, g=0.7, b=1})
                            bar:SetStatusBarColor(cSide.r, cSide.g, cSide.b)
                            bar:Show()
                            yOffset = yOffset - (ASSETS.barHeight + 4)
                            barIdx = barIdx + 1
                        end
                    end
                end
            end

            if self.RenderBonusObjectiveBar then
                 local newY, newL, newB, rendered = self:RenderBonusObjectiveBar(qID, lineIdx, barIdx, width, yOffset)
                 if rendered then
                      yOffset = newY; lineIdx = newL; barIdx = newB
                 end
            end
            yOffset = yOffset - 2
        end
        yOffset = yOffset - (ASSETS.spacing or 10)
    end

    local iconCamp = (ASSETS.icons and ASSETS.icons.campaign) or nil
    local iconWQ = (ASSETS.icons and ASSETS.icons.wq) or nil

    RenderSection("Campaign", iconCamp, campaignQuests, false)
    RenderSection("World Quests", iconWQ, worldQuests, false)

    if #sideQuestsZoneOrder > 0 then
        local hLine = self:GetLine(lineIdx)
        -- [FIX] Usar self.Content
        hLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
        hLine.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
        self.SafelySetText(hLine.text, "  SIDE QUESTS")
        if hLine.separator then hLine.separator:Show() end
        hLine:Show()
        yOffset = yOffset - (hHead + 4)
        lineIdx = lineIdx + 1

        for _, mapID in ipairs(sideQuestsZoneOrder) do
            local mapInfo = C_Map.GetMapInfo(mapID)
            local zoneName = (mapInfo and mapInfo.name)
            RenderSection(zoneName, nil, sideQuests[mapID], true)
        end
    end

    return yOffset, lineIdx, barIdx, itemIdx
end
