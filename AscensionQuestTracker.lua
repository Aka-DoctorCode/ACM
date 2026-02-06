--------------------------------------------------------------------------------
-- NAMESPACE & CONSTANTS
--------------------------------------------------------------------------------
local addonName, addonTable = ...
local AQT = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)

--------------------------------------------------------------------------------
-- LOCALIZATION
--------------------------------------------------------------------------------
local L = LibStub("AceLocale-3.0"):GetLocale("AscensionQuestTracker", true)

-- VISUAL ASSETS
local ASSETS = {
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
    }
}

--------------------------------------------------------------------------------
-- OPTIMIZATION: POOLED TABLES (Reduce GC)
--------------------------------------------------------------------------------
local pooled_quests = {}
local pooled_grouped = {}
local pooled_zoneOrder = {}
local pooled_watchedIDs = {}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local function SafelySetText(fontString, text)
    if not fontString or type(fontString) ~= "table" then return end
    fontString:SetText(text or "")
end

local function FormatTime(seconds)
    if not seconds or type(seconds) ~= "number" then return "00:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d", m, s)
end

local function SafePlaySound(soundID)
    if not soundID then return end
    pcall(PlaySound, soundID)
end

local function GetQuestDistanceStr(questID)
    if not C_QuestLog.GetDistanceSqToQuest then return nil end
    local distSq = C_QuestLog.GetDistanceSqToQuest(questID)
    if not distSq or distSq < 0 then return nil end
    local yards = math.sqrt(distSq)
    return string.format("%dyd", math.floor(yards))
end

--------------------------------------------------------------------------------
-- UI OBJECT POOLS
--------------------------------------------------------------------------------

AQT.lines = {}
AQT.bars = {}
AQT.itemButtons = {}
AQT.completions = {} -- Store quest completion state for sound notifications
AQT.inBossCombat = false

    AQT.GetLine = function(self, index)
    if not self.lines[index] then
        local f = CreateFrame("Button", nil, self)
        f:SetSize(200, 16)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetAllPoints(f)
        f.text:SetJustifyH("RIGHT")
        f.text:SetWordWrap(false)
        f.text:SetShadowColor(0, 0, 0, 1)
        f.text:SetShadowOffset(1, -1)
        
        f.icon = f:CreateTexture(nil, "ARTWORK")
        f.icon:SetSize(14, 14)
        
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.lines[index] = f
    end
    local line = self.lines[index]
    line:EnableMouse(false)
    line:SetScript("OnClick", nil)
    line:SetScript("OnEnter", nil)
    line:SetScript("OnLeave", nil)
    line.text:SetAlpha(1)
    line.text:SetTextColor(1, 1, 1)
    if line.icon then line.icon:Hide() end
    return line
end

AQT.GetBar = function(self, index)
    if not self.bars[index] then
        local b = CreateFrame("StatusBar", nil, self, "BackdropTemplate")
        b:SetStatusBarTexture(ASSETS.barTexture)
        b:SetMinMaxValues(0, 1)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ASSETS.barTexture)
        bg:SetAllPoints(true)
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
        b.bg = bg
        self.bars[index] = b
    end
    return self.bars[index]
end

-- Secure Item Button Pool
AQT.GetItemButton = function(self, index)
    if not self.itemButtons[index] then
        local name = "AQTItemButton" .. index
        local b = CreateFrame("Button", name, self, "SecureActionButtonTemplate")
        b:SetSize(22, 22)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        
        -- Click handlers
        -- Use AnyUp, AnyDown to match !KalielsTracker ActiveButton behavior
        b:RegisterForClicks("AnyUp", "AnyDown")
        
        b:SetScript("OnEnter", function(self)
            local questLogIndex = self:GetAttribute("questLogIndex")
            if questLogIndex then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetQuestLogSpecialItem(questLogIndex)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        -- Hook for Shift-Click Chat Link (Preserves SecureActionButton logic)
        b:HookScript("OnClick", function(self)
            if IsShiftKeyDown() and self.itemLink then
                ChatEdit_InsertLink(self.itemLink)
            end
        end)
        
        self.itemButtons[index] = b
    end
    return self.itemButtons[index]
end

--------------------------------------------------------------------------------
-- RENDER MODULES
--------------------------------------------------------------------------------

-- 1. SCENARIOS (M+, Delves)
local function RenderScenario(startY, lineIdx, barIdx)
    local yOffset = startY
    if not C_Scenario or not C_Scenario.IsInScenario() then return yOffset, lineIdx, barIdx end

    local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260

    -- Scenario Configs
    local db = AscensionQuestTrackerDB and AscensionQuestTrackerDB.scenario or {}
    local titleSize = db.titleSize or ASSETS.fontHeaderSize
    local descSize = db.descSize or ASSETS.fontTextSize
    local objSize = db.objSize or ASSETS.fontTextSize
    local barHeight = db.barHeight or ASSETS.barHeight
    local barColor = db.barColor or ASSETS.colors.quest

    local timerID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if timerID then
        local level = (C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo())
        local _, _, timeLimit = (C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(timerID))
        local _, elapsedTime = GetWorldElapsedTime(1)
        local timeRem = (timeLimit or 0) - (elapsedTime or 0)

        local header = AQT:GetLine(lineIdx)
        header.text:SetFont(ASSETS.font, titleSize + 2, "OUTLINE")
        header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        header:SetWidth(width - 20)
        SafelySetText(header.text, string.format(L["+%d Keystone"], level or 0))
        header:Show()
        yOffset = yOffset - 18
        lineIdx = lineIdx + 1

        local timerLine = AQT:GetLine(lineIdx)
        timerLine.text:SetFont(ASSETS.font, 18, "OUTLINE")
        timerLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        timerLine:SetWidth(width - 20)
        SafelySetText(timerLine.text, FormatTime(timeRem))
        timerLine:Show()
        yOffset = yOffset - 22
        lineIdx = lineIdx + 1

        local timeBar = AQT:GetBar(barIdx)
        timeBar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
        timeBar:SetSize(width - 20, 6)
        timeBar:SetMinMaxValues(0, timeLimit or 1)
        timeBar:SetValue(timeLimit - timeRem)
        
        if timeRem < 60 then
            timeBar:SetStatusBarColor(ASSETS.colors.timerLow.r, ASSETS.colors.timerLow.g, ASSETS.colors.timerLow.b)
        else
            timeBar:SetStatusBarColor(ASSETS.colors.timerHigh.r, ASSETS.colors.timerHigh.g, ASSETS.colors.timerHigh.b)
        end
        timeBar:Show()
        yOffset = yOffset - 12
        barIdx = barIdx + 1
    end
    
    -- Scenario Objectives
    local foundObjectives = false
        
        -- A. Try C_Scenario (Modern Dungeons/Scenarios)
        if C_Scenario and C_Scenario.GetInfo then
             local name, currentStage, numStages, _, _, _, _, _, _, _, _, _, scenarioType = C_Scenario.GetInfo()
             if name then
                 foundObjectives = true
                 
                 -- Header (Dungeon Name)
                 local header = AQT:GetLine(lineIdx)
                 header.text:SetFont(ASSETS.font, titleSize, "OUTLINE")
                 header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                 header:SetWidth(width - 20)
                 header.text:SetTextColor(ASSETS.colors.header.r, ASSETS.colors.header.g, ASSETS.colors.header.b)
                 SafelySetText(header.text, name)
                 header:Show()
                 yOffset = yOffset - 16
                 lineIdx = lineIdx + 1
                 
                 -- Stage Info
                 -- Capture all returns to find weightedProgress (usually 9th return in Retail)
                 local stageName, stageDesc, numCriteria, stepFailed, isBonusStep, isForCurrentStepOnly, shouldShowBonusObjective, spells, weightedProgress, rewardQuestID, widgetSetID, stepID = C_Scenario.GetStepInfo()
                 
                 -- Helper to apply tooltip to any frame in this scenario
                 local function ApplyScenarioTooltip(f)
                    if not f then return end
                    f:EnableMouse(true)
                    f:SetScript("OnEnter", function(self)
                       GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                       if currentStage and numStages and currentStage <= numStages then
                           GameTooltip:AddLine(string.format(SCENARIO_STAGE_STATUS, currentStage, numStages), 1, 0.82, 0)
                           GameTooltip:AddLine(stageName, 1, 1, 1)
                           GameTooltip:AddLine(" ")
                           GameTooltip:AddLine(stageDesc, 1, 0.82, 0, true)
                           GameTooltip:Show()
                       end
                    end)
                    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
                 end

                 if stageName and stageName ~= "" then
                    ApplyScenarioTooltip(header) -- Always apply to header

                    if stageName ~= name then
                         local sLine = AQT:GetLine(lineIdx)
                         sLine.text:SetFont(ASSETS.font, descSize, "OUTLINE")
                         sLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                         sLine:SetWidth(width - 20)
                         SafelySetText(sLine.text, stageName)
                         sLine.text:SetTextColor(1, 0.82, 0) -- Gold for stage
                         
                         ApplyScenarioTooltip(sLine)
                         
                         sLine:Show()
                         yOffset = yOffset - 14
                         lineIdx = lineIdx + 1
                    end
                 end
                 
                 -- 1. Step-level Weighted Progress (Scenario Bar)
                if weightedProgress and type(weightedProgress) == "number" then
                    -- If the step itself has progress, show it as the main objective
                     local pLine = AQT:GetLine(lineIdx)
                     pLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                     pLine:SetWidth(width - 20)
                     pLine.text:SetFont(ASSETS.font, objSize, "OUTLINE")
                     SafelySetText(pLine.text, string.format("%s (%d%%)", stageDesc or stageName, weightedProgress))
                     if ApplyScenarioTooltip then ApplyScenarioTooltip(pLine) end
                     pLine:Show()
                     
                     local spacing = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.barSpacing) or 8
                     yOffset = yOffset - spacing
                     
                     local bar = AQT:GetBar(barIdx)
                     bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                     -- local width is already defined at top of function
                     bar:SetSize(width - 20, barHeight)
                     bar:SetMinMaxValues(0, 100)
                     bar:SetValue(weightedProgress)
                     bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
                     bar:Show()
                     
                     yOffset = yOffset - 10
                     barIdx = barIdx + 1
                     lineIdx = lineIdx + 1
                 else
                     -- 2. Individual Criteria
                     local cnt = numCriteria or 0
                     for i = 1, cnt do
                        local name, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress
                        
                        -- Priority 1: C_ScenarioInfo.GetCriteriaInfo (Modern Retail)
                        if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
                            local cInfo = C_ScenarioInfo.GetCriteriaInfo(i)
                            if cInfo then
                                name = cInfo.description
                                criteriaType = cInfo.criteriaType
                                completed = cInfo.completed
                                quantity = cInfo.quantity
                                totalQuantity = cInfo.totalQuantity
                                flags = cInfo.flags
                                assetID = cInfo.assetID
                                quantityString = cInfo.quantityString
                                criteriaID = cInfo.criteriaID
                                duration = cInfo.duration
                                elapsed = cInfo.elapsed
                                criteriaFailed = cInfo.failed
                                isWeightedProgress = cInfo.isWeightedProgress
                            end
                        end

                        -- Priority 2: C_Scenario.GetCriteriaInfo (SylingTracker / Modern Table API)
                        if (not name or name == "") and C_Scenario.GetCriteriaInfo then
                             local arg1 = C_Scenario.GetCriteriaInfo(i)
                             if type(arg1) == "table" then
                                 -- Table return style (Modern Retail)
                                 local cInfo = arg1
                                 name = cInfo.description
                                 criteriaType = cInfo.criteriaType
                                 completed = cInfo.completed
                                 quantity = cInfo.quantity
                                 totalQuantity = cInfo.totalQuantity
                                 flags = cInfo.flags
                                 assetID = cInfo.assetID
                                 quantityString = cInfo.quantityString
                                 criteriaID = cInfo.criteriaID
                                 duration = cInfo.duration
                                 elapsed = cInfo.elapsed
                                 criteriaFailed = cInfo.failed
                                 isWeightedProgress = cInfo.isWeightedProgress
                             elseif type(arg1) == "string" then
                                 -- Multi-value return style (Legacy / Classic)
                                 local _
                                 name, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress = C_Scenario.GetCriteriaInfo(i)
                             end
                        end

                        -- Fallback: Try GetStepCriteriaInfo (If GetCriteriaInfo failed or missing)
                        if (not name or name == "") and C_Scenario.GetStepCriteriaInfo then
                            name, criteriaType, completed, quantity, totalQuantity, flags, assetID, quantityString, criteriaID, duration, elapsed, criteriaFailed, isWeightedProgress = C_Scenario.GetStepCriteriaInfo(i)
                        end
                        
                        if name and name ~= "" then
                            local line = AQT:GetLine(lineIdx)
                            line.text:SetFont(ASSETS.font, objSize, "OUTLINE")
                            line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                            line:SetWidth(width - 20)
                            
                            local text = "- " .. name
                            if totalQuantity and totalQuantity > 0 then
                                text = string.format("- %s: %d/%d", name, quantity, totalQuantity)
                            end
                            if isWeightedProgress then
                                 text = string.format("- %s: %d%%", name, quantity)
                            end
                            
                            -- Colorize based on completion
                            if completed then
                                line.text:SetTextColor(ASSETS.colors.complete.r, ASSETS.colors.complete.g, ASSETS.colors.complete.b)
                            else
                                line.text:SetTextColor(1, 1, 1)
                            end
                            
                            SafelySetText(line.text, text)
                            if ApplyScenarioTooltip then ApplyScenarioTooltip(line) end
                            line:Show()
                            
                            -- Check for WeightedProgress (Percentage) OR standard progress
                            local showBar = false
                            local barMax = totalQuantity
                            local barVal = quantity
                            
                            -- Enemy Forces (Trash) special handling
                            if isWeightedProgress and quantityString then
                                -- quantityString might be "85%" or similar
                                -- Try to parse quantity from string if quantity is 0 or nil, but usually quantity is correct
                                -- SylingTracker: quantity = tonumber(strsub(criteriaInfo.quantityString, 1, -2))
                                if (not quantity or quantity == 0) and string.find(quantityString, "%%") then
                                     local val = tonumber(string.sub(quantityString, 1, -2))
                                     if val then quantity = val end
                                end
                            end

                            if not completed then
                                if isWeightedProgress then
                                    showBar = true
                                    barMax = 100
                                    barVal = quantity
                                elseif totalQuantity and totalQuantity > 1 then
                                    showBar = true
                                end
                            end

                            if showBar then
                                local spacing = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.barSpacing) or 8
                                yOffset = yOffset - spacing
                                
                                local bar = AQT:GetBar(barIdx)
                                bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                                -- local width is already defined at top of function
                                bar:SetSize(width - 20, barHeight)
                                bar:SetMinMaxValues(0, barMax)
                                bar:SetValue(barVal)
                                bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
                                bar:Show()
                                
                                yOffset = yOffset - 10
                                barIdx = barIdx + 1
                            else
                                yOffset = yOffset - 14
                            end

                            lineIdx = lineIdx + 1
                        end
                    end
                  end
            end
        end

        -- B. Try WorldStateUI (Legacy/PvP/Custom Ascension fallback) - Only if no Scenario found
        if not foundObjectives and GetNumWorldStateUI then
            local numUI = GetNumWorldStateUI()
            if numUI > 0 then
                -- Check if we have valid states to show
                local hasValidState = false
                for i = 1, numUI do
                    local _, state, _, text = GetWorldStateUIInfo(i)
                    if state and state > 0 and text and text ~= "" then
                        hasValidState = true
                        break
                    end
                end

                if hasValidState then
                    -- Use Instance Name as Header
                    local name = GetInstanceInfo()
                    if not name or name == "" then name = L["Dungeon Objectives"] end
                    
                    local header = AQT:GetLine(lineIdx)
                    header.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
                    header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                    header:SetWidth(width - 20)
                    header.text:SetTextColor(ASSETS.colors.header.r, ASSETS.colors.header.g, ASSETS.colors.header.b)
                    SafelySetText(header.text, name)
                    header:Show()
                    yOffset = yOffset - 16
                    lineIdx = lineIdx + 1

                    for i = 1, numUI do
                        local _, state, _, text = GetWorldStateUIInfo(i)
                        if state and state > 0 and text and text ~= "" then
                             local line = AQT:GetLine(lineIdx)
                            line.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                            line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                            line:SetWidth(width - 20)
                            SafelySetText(line.text, text)
                            
                            -- Simple coloring for WorldStates? Usually they are just text.
                            line.text:SetTextColor(1, 1, 1)
                            
                            line:Show()
                            yOffset = yOffset - 14
                            lineIdx = lineIdx + 1
                        end
                    end
                end
            end
        end
    
    return yOffset - ASSETS.spacing, lineIdx, barIdx
end

-- 2. QUESTS (GROUPED BY ZONE + DISTANCE SORTED)
-- Helper for creating macros (Legacy - Removed)
-- local function GetOrCreateMacro(index, itemID)
-- end

local function RenderQuests(startY, lineIdx, barIdx, itemIdx)
    local shouldHide = AscensionQuestTrackerDB and AscensionQuestTrackerDB.hideOnBoss
    if shouldHide and AQT.inBossCombat then return startY, lineIdx, barIdx, itemIdx end

    local yOffset = startY
    if not C_QuestLog or not C_QuestLog.GetNumQuestWatches then return yOffset, lineIdx, barIdx, itemIdx end

    local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260
    local superTrackedQuestID = (C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()) or (GetSuperTrackedQuestID and GetSuperTrackedQuestID())

    -- 1. Gather & Sort Data
    table.wipe(pooled_quests)
    table.wipe(pooled_watchedIDs)
    local watchedMap = {}
    
    -- Standard Watches
    if C_QuestLog.GetQuestIDForWatch then
        local numWatches = C_QuestLog.GetNumQuestWatches()
        for i = 1, numWatches do
            local id = C_QuestLog.GetQuestIDForWatch(i)
            if id then 
                table.insert(pooled_watchedIDs, id) 
                watchedMap[id] = true
            end
        end
    elseif C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and C_QuestLog.GetQuestWatchType(info.questID) ~= nil then
                table.insert(pooled_watchedIDs, info.questID)
                watchedMap[info.questID] = true
            end
        end
    end

    -- World Quest Watches (Manually tracked WQs)
    if C_QuestLog.GetNumWorldQuestWatches then
        local numWQWatches = C_QuestLog.GetNumWorldQuestWatches()
        for i = 1, numWQWatches do
            local id = C_QuestLog.GetQuestIDForWorldQuestWatchIndex(i)
            if id and not watchedMap[id] then
                table.insert(pooled_watchedIDs, id)
                watchedMap[id] = true
            end
        end
    end

    -- World Quests / Tasks (Hardcoded always show)
    if GetTasksTable then
        local tasks = GetTasksTable()
        for _, qID in ipairs(tasks) do
            if not watchedMap[qID] then
                local isWQ = false
                if C_QuestLog.IsWorldQuest then
                    isWQ = C_QuestLog.IsWorldQuest(qID)
                end
                
                local isInArea = false
                if GetTaskInfo then
                    isInArea = GetTaskInfo(qID)
                else
                    isInArea = true 
                end
                
                -- Track if it's a WQ OR if it's a local Bonus Objective (isInArea)
                if isWQ or isInArea then
                    table.insert(pooled_watchedIDs, qID)
                    watchedMap[qID] = true
                    
                    -- Request load to ensure objectives are available
                    if C_QuestLog.RequestLoadQuestByID then
                        C_QuestLog.RequestLoadQuestByID(qID)
                    end
                end
            end
        end
    end

    -- 1.5 Build Header Map (Map QuestIDs to their Log Headers)
    local headerMap = {}
    local currentHeader = L["Miscellaneous"]
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerMapName = L["Unknown Zone"]
    if playerMapID then
        local pMapInfo = C_Map.GetMapInfo(playerMapID)
        if pMapInfo and pMapInfo.name then
            playerMapName = pMapInfo.name
        end
    end
    
    if C_QuestLog.GetNumQuestLogEntries then
        for i = 1, C_QuestLog.GetNumQuestLogEntries() do
            local info = C_QuestLog.GetInfo(i)
            if info then
                if info.isHeader then
                    currentHeader = info.title
                else
                    headerMap[info.questID] = currentHeader
                end
            end
        end
    end

    for _, qID in ipairs(pooled_watchedIDs) do
        local logIdx = C_QuestLog.GetLogIndexForQuestID(qID)
        local info = nil
        if logIdx then info = C_QuestLog.GetInfo(logIdx) end
        
        -- Robust WQ Detection
        local isWorldQuest = false
        if QuestUtils_IsQuestWorldQuest then
            isWorldQuest = QuestUtils_IsQuestWorldQuest(qID)
        elseif C_QuestLog.IsWorldQuest then
            isWorldQuest = C_QuestLog.IsWorldQuest(qID)
        end
        
        -- Fallback: If no log info but has Task info, treat as WQ
        if not info and not isWorldQuest and GetTaskInfo then
            local isInArea = GetTaskInfo(qID)
            if isInArea then isWorldQuest = true end
        end

        -- Handle WQs that might not have log info OR are hidden but shouldn't be
        if isWorldQuest then
            if not info then
                info = { 
                    title = C_QuestLog.GetTitleForQuestID(qID) or "", 
                    mapID = 0, 
                    isHidden = false, 
                    questID = qID,
                    isWorldQuest = true
                }
            elseif info.isHidden then
                -- Force show WQs even if marked hidden
                 info.isHidden = false
            end

            if GetTaskInfo then
                 local _, _, _, questName = GetTaskInfo(qID)
                 if questName then info.title = questName end
            end
            if info.title == "" then info.title = "World Quest" end
            
            if C_TaskQuest and C_TaskQuest.GetQuestZoneID then
                info.mapID = C_TaskQuest.GetQuestZoneID(qID)
            end
        end

        if info and not info.isHidden then
            local dist = 999999999
            if C_QuestLog.GetDistanceSqToQuest then
                dist = C_QuestLog.GetDistanceSqToQuest(qID) or 999999999
            end
            if qID == superTrackedQuestID then dist = -1 end -- Top priority
            
            -- WQ Time Remaining
            local timeRem = 0
            if C_TaskQuest and C_TaskQuest.GetQuestTimeLeftMinutes then
                timeRem = C_TaskQuest.GetQuestTimeLeftMinutes(qID) or 0
            end

            -- Determine Zone Name
            local zName = headerMap[qID]
            if not zName then
                if info.mapID and info.mapID > 0 then
                    local mInfo = C_Map.GetMapInfo(info.mapID)
                    if mInfo and mInfo.name then
                        zName = mInfo.name
                    end
                end
            end
            if not zName then zName = L["Unknown Zone"] end
            
            -- Capture Task Info for sorting
            local isInArea, isOnMap = false, false
            if GetTaskInfo then
                isInArea, isOnMap = GetTaskInfo(qID)
            end

            table.insert(pooled_quests, {
                id = qID,
                info = info,
                distValue = dist,
                zoneName = zName,
                timeRem = timeRem,
                isWorldQuest = isWorldQuest,
                isInArea = isInArea,
                isOnMap = isOnMap
            })
        end
    end

    table.sort(pooled_quests, function(a, b) 
        -- 1. Super Tracked always first
        if a.id == superTrackedQuestID then return true end
        if b.id == superTrackedQuestID then return false end
        
        -- 2. In-Area / On-Map Priority
        if a.isInArea ~= b.isInArea then return a.isInArea end
        if a.isOnMap ~= b.isOnMap then return a.isOnMap end
        
        -- 3. Distance
        return a.distValue < b.distValue 
    end)

    -- 2. Group by Zone Name
    table.wipe(pooled_grouped)
    table.wipe(pooled_zoneOrder)
    
    for _, q in ipairs(pooled_quests) do
        if not pooled_grouped[q.zoneName] then
            pooled_grouped[q.zoneName] = {}
            table.insert(pooled_zoneOrder, q.zoneName)
        end
        table.insert(pooled_grouped[q.zoneName], q)
    end

    -- 3. Render
    for _, zName in ipairs(pooled_zoneOrder) do
        -- Zone Header Logic
        local showHeader = AscensionQuestTrackerDB.showAllZoneHeaders
        if not showHeader then
            for _, q in ipairs(pooled_grouped[zName]) do
                if q.id == superTrackedQuestID then
                    showHeader = true
                    break
                end
            end
        end

        if showHeader then
            local zLine = AQT:GetLine(lineIdx)
            zLine.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize - 1, "OUTLINE")
            zLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
            zLine:SetWidth(width - 20)
            zLine.text:SetTextColor(ASSETS.colors.zone.r, ASSETS.colors.zone.g, ASSETS.colors.zone.b)
            SafelySetText(zLine.text, zName)
            zLine:Show()
            yOffset = yOffset - 14
            lineIdx = lineIdx + 1
        end

        for _, quest in ipairs(pooled_grouped[zName]) do
            local qID = quest.id
            local info = quest.info
            local isComplete = C_QuestLog.IsComplete(qID)
            local isWorldQuest = quest.isWorldQuest
            local isSuperTracked = (qID == superTrackedQuestID)

            -- Notification Sound
            if isComplete and not AQT.completions[qID] then
                if SOUNDKIT and SOUNDKIT.UI_QUEST_COMPLETE then
                    SafePlaySound(SOUNDKIT.UI_QUEST_COMPLETE)
                end
                AQT.completions[qID] = true
            elseif not isComplete then
                AQT.completions[qID] = nil
            end
            
            -- Config Retrieval
            local wqDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.worldQuest
            local focusDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.focused
            local questDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.quest
            
            -- Color Logic
            local color = ASSETS.colors.quest
            local barColor = ASSETS.colors.quest
            
            -- Apply Quest Defaults first
            if questDB and questDB.titleColor then color = questDB.titleColor end
            if questDB and questDB.barColor then barColor = questDB.barColor end
            
            if info.campaignID and info.campaignID > 0 then 
                color = ASSETS.colors.campaign 
                barColor = ASSETS.colors.campaign
            end
            
            if isWorldQuest then 
                color = ASSETS.colors.wq 
                barColor = ASSETS.colors.wq
                if wqDB and wqDB.titleColor then
                    color = wqDB.titleColor
                end
                if wqDB and wqDB.barColor then
                    barColor = wqDB.barColor
                end
            end
            
            if isComplete then 
                color = ASSETS.colors.complete 
                barColor = ASSETS.colors.complete
            end
            
            if isSuperTracked then 
                color = ASSETS.colors.active 
                barColor = ASSETS.colors.active
                if focusDB and focusDB.titleColor then
                    color = focusDB.titleColor
                end
                if focusDB and focusDB.barColor then
                    barColor = focusDB.barColor
                end
            end

            -- Quest Item Check
            local itemLink, itemIcon, itemCount, showItemWhenComplete 
            local logIndex = C_QuestLog.GetLogIndexForQuestID(qID)
            if logIndex then
                itemLink, itemIcon, itemCount, showItemWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
            end

            -- Title
            local title = AQT:GetLine(lineIdx)
            title:EnableMouse(true)
            title:SetSize(width - (itemIcon and 30 or 0), 16)
            title:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
            
            local titleFontSize = ASSETS.fontHeaderSize
            if isWorldQuest and wqDB and wqDB.titleSize then
                titleFontSize = wqDB.titleSize
            elseif not isWorldQuest and questDB and questDB.titleSize then
                titleFontSize = questDB.titleSize
            end
            title.text:SetFont(ASSETS.font, titleFontSize, "OUTLINE")
            
            title.text:SetTextColor(color.r, color.g, color.b)

            local distStr = GetQuestDistanceStr(qID)
            local displayText = info.title
            
            -- WQ Timer
            if quest.timeRem > 0 and quest.timeRem < 1440 then -- Less than 24h
                 local timeStr
                 if quest.timeRem >= 60 then
                     local hrs = math.floor(quest.timeRem / 60)
                     timeStr = string.format("%d hr", hrs)
                 else
                     timeStr = string.format("%d min", quest.timeRem)
                 end
                 displayText = string.format("[%s] %s", timeStr, displayText)
            end
            
            if distStr then displayText = string.format("[%s] %s", distStr, displayText) end
            if isSuperTracked then displayText = "> " .. displayText end
            if isComplete then displayText = displayText .. " " .. L["(Ready)"] end
            SafelySetText(title.text, displayText)
            
            -- Campaign Icon
            if info.campaignID and info.campaignID > 0 then
                title.icon:SetTexture(4620677)
                title.icon:ClearAllPoints()
                local w = title.text:GetStringWidth()
                title.icon:SetPoint("RIGHT", title, "RIGHT", -w - 4, 0)
                title.icon:Show()
            end

            -- Render Item Button (After text to calculate position)
            if itemIcon and (not isComplete or showItemWhenComplete) then
                if not InCombatLockdown() then
                    local textWidth = title.text:GetStringWidth()
                    local basePointX = -ASSETS.padding - textWidth - 5
                    
                    local itemID
                    if itemLink then
                        itemID = GetItemInfoInstant(itemLink)
                        if not itemID then
                            itemID = tonumber(itemLink:match("item:(%d+)"))
                        end
                    end
                    
                    if itemID then
                        local iBtn = AQT:GetItemButton(itemIdx)
                        iBtn:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", basePointX, yOffset + 3)
                        iBtn.icon:SetTexture(itemIcon)
                        iBtn.icon:SetVertexColor(1, 1, 1) -- Reset color
                        iBtn.count:SetText("")
                        
                        -- Reset Attributes
                        iBtn:SetAttribute("type", nil)
                        iBtn:SetAttribute("type1", nil)
                        iBtn:SetAttribute("type2", nil)
                        iBtn:SetAttribute("item", nil)
                        iBtn:SetAttribute("macrotext", nil)
                        iBtn:SetAttribute("macro", nil)
                        iBtn:SetAttribute("unit", nil)

                        iBtn.itemLink = itemLink -- Store for HookScript
                        
                        iBtn:SetAttribute("type", "item")
                        iBtn:SetAttribute("item", itemLink)
                        iBtn:SetAttribute("type1", "item")
                        iBtn:SetAttribute("type2", "item")
                        
                        if logIndex then
                             iBtn:SetAttribute("questLogIndex", logIndex)
                        end
                        
                        -- Tooltip
                        iBtn:SetScript("OnEnter", function(self)
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            if itemLink then
                                GameTooltip:SetHyperlink(itemLink)
                            else
                                GameTooltip:SetItemByID(itemID)
                            end
                            GameTooltip:AddLine(" ")
                            GameTooltip:AddLine(L["Click to use item"], 0, 1, 0)
                            
                            if IsShiftKeyDown() then GameTooltip:AddLine(L["Shift-Click: Link to Chat"], 0.8, 0.8, 0.8) end
                            GameTooltip:Show()
                        end)
                        iBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        
                        iBtn:SetFrameLevel(title:GetFrameLevel() + 10)
                        iBtn:Show()
                        itemIdx = itemIdx + 1
                    else
                        -- Fallback for no ID
                    end
                end
            end

            -- Interaction
            title:SetScript("OnClick", function(_, btn)
                if IsShiftKeyDown() and btn == "LeftButton" then
                    local link = GetQuestLink(qID)
                    if link then ChatEdit_InsertLink(link) end
                    return
                end
                
                if btn == "LeftButton" then
                    C_SuperTrack.SetSuperTrackedQuestID(qID)
                    C_QuestLog.SetSelectedQuest(qID)
                    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
                        SafePlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
                    end
                elseif btn == "RightButton" then
                    -- Detect Precise Type
                    local isRealWQ = false
                    if C_QuestLog.IsWorldQuest then isRealWQ = C_QuestLog.IsWorldQuest(qID) end
                    
                    local isBonus = false
                    if not isRealWQ and GetTaskInfo then
                        local isInArea = GetTaskInfo(qID)
                        if isInArea then isBonus = true end
                    end

                    -- 1. Events/Scenarios (Bonus Objectives) -> No Menu
                    if isBonus then
                        return
                    end

                    -- 2. World Quests -> Restricted Menu
                    if isRealWQ then
                        if MenuUtil and MenuUtil.CreateContextMenu then
                            MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                                rootDescription:CreateTitle(info.title)
                                rootDescription:CreateButton(L["Focus / SuperTrack"], function() C_SuperTrack.SetSuperTrackedQuestID(qID) end)
                                rootDescription:CreateButton(L["Open Map"], function() QuestMapFrame_OpenToQuestDetails(qID) end)
                                rootDescription:CreateButton(L["Share"], function() C_QuestLog.ShareQuest(qID) end)
                            end)
                        end
                        return
                    end

                    -- 3. Normal Quests -> Full Menu
                    if MenuUtil and MenuUtil.CreateContextMenu then
                        -- Modern Context Menu (MenuUtil)
                        MenuUtil.CreateContextMenu(UIParent, function(owner, rootDescription)
                            rootDescription:CreateTitle(info.title)
                            rootDescription:CreateButton(L["Focus / SuperTrack"], function() C_SuperTrack.SetSuperTrackedQuestID(qID) end)
                            rootDescription:CreateButton(L["Open Map"], function() QuestMapFrame_OpenToQuestDetails(qID) end)
                            rootDescription:CreateButton(L["Share"], function() C_QuestLog.ShareQuest(qID) end)
                            rootDescription:CreateButton(L["|cffff4444Abandon|r"], function() QuestMapFrame_AbandonQuest(qID) end)
                            rootDescription:CreateButton(L["Stop Tracking"], function() C_QuestLog.RemoveQuestWatch(qID) end)
                        end)
                    else
                        -- Fallback for older clients: Just remove watch
                        C_QuestLog.RemoveQuestWatch(qID)
                    end
                end
            end)

            title:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                if not pcall(GameTooltip.SetHyperlink, GameTooltip, "quest:"..qID) then
                     if logIndex then
                        GameTooltip:SetQuestLogItem(logIndex)
                     else
                        GameTooltip:SetText(info.title)
                     end
                end
                
                -- Add explicit rewards summary if needed (basic rewards are usually in the item tooltip)
                local xp = GetQuestLogRewardXP(qID) or 0
                local money = GetQuestLogRewardMoney(qID) or 0
                if xp > 0 or money > 0 then
                     GameTooltip:AddLine(" ")
                     GameTooltip:AddLine(L["Rewards:"], 1, 0.8, 0)
                     if xp > 0 then GameTooltip:AddLine(string.format(L["XP: %d"], xp), 1, 1, 1) end
                     if money > 0 then GameTooltip:AddLine(GetMoneyString(money), 1, 1, 1) end
                end

                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("|cff00ffff" .. L["Shift-Click: Link to Chat"] .. "|r", 0, 1, 1)
                GameTooltip:AddLine("|cffffaa00" .. L["Right-Click: Context Menu"] .. "|r", 1, 0.6, 0)
                GameTooltip:Show()
            end)
            title:SetScript("OnLeave", function() GameTooltip:Hide() end)

            title:Show()
            yOffset = yOffset - 15
            lineIdx = lineIdx + 1

            -- Campaign Progress
            if info.campaignID and C_CampaignInfo then
                local cInfo = C_CampaignInfo.GetCampaignInfo(info.campaignID)
                if cInfo then
                     local cLine = AQT:GetLine(lineIdx)
                     cLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                     cLine:SetWidth(width - 20)
                     cLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize - 1, "ITALIC")
                     -- Example: "The War Within (2/5)"
                     local text = cInfo.name 
                     if cInfo.chapterID and C_CampaignInfo.GetChapterInfo then
                         local chInfo = C_CampaignInfo.GetChapterInfo(cInfo.chapterID)
                         if chInfo and chInfo.name then text = text .. ": " .. chInfo.name end
                     end
                     SafelySetText(cLine.text, text)
                     cLine.text:SetTextColor(ASSETS.colors.campaign.r, ASSETS.colors.campaign.g, ASSETS.colors.campaign.b)
                     cLine:Show()
                     yOffset = yOffset - 10
                     lineIdx = lineIdx + 1
                end
            end

            -- Objectives
            local objectivesHaveBar = false
            if not isComplete then
                local objectives = C_QuestLog.GetQuestObjectives(qID)
                local numObjectives = 0
                if objectives then numObjectives = #objectives end
                
                -- Fallback for WQs if C_QuestLog.GetQuestObjectives returns nothing
                if numObjectives == 0 and isWorldQuest then
                    if GetTaskInfo and GetQuestObjectiveInfo then
                        local _, _, num = GetTaskInfo(qID)
                        if num and num > 0 then
                            objectives = {}
                            for i=1, num do
                                local text, oType, finished = GetQuestObjectiveInfo(qID, i, false)
                                
                                -- Handle progress bar type with missing text
                                if oType == "progressbar" and GetQuestProgressBarPercent then
                                     local pct = GetQuestProgressBarPercent(qID)
                                     if pct then 
                                        text = string.format("%d%%", pct)
                                        -- Allow bar rendering
                                        table.insert(objectives, { text = text, finished = finished, numRequired = 100, numFulfilled = pct })
                                     end
                                elseif text and text ~= "" then
                                    table.insert(objectives, { text = text, finished = finished, numRequired = 0, numFulfilled = 0 })
                                end
                            end
                        end
                    end
                end
                
                for _, obj in ipairs(objectives or {}) do
                    if obj.text and not obj.finished then
                        local oLine = AQT:GetLine(lineIdx)
                        oLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                        oLine:SetWidth(width - 20) -- Fix text truncation
                        
                        local objFontSize = ASSETS.fontTextSize
                        if isWorldQuest and wqDB and wqDB.objSize then
                            objFontSize = wqDB.objSize
                        elseif not isWorldQuest and questDB and questDB.objSize then
                            objFontSize = questDB.objSize
                        end
                        oLine.text:SetFont(ASSETS.font, objFontSize, "OUTLINE")
                        
                        SafelySetText(oLine.text, obj.text)
                        oLine:Show()
                        -- Dynamic spacing based on configuration
                        local spacing = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.barSpacing) or 8
                        
                        if obj.numRequired and obj.numRequired > 0 then
                            -- Apply spacing BEFORE the bar (between text and bar)
                            yOffset = yOffset - spacing
                        else
                            -- Default spacing if no bar
                            yOffset = yOffset - 12
                        end
                        
                        lineIdx = lineIdx + 1

                        if obj.numRequired and obj.numRequired > 1 then
                            objectivesHaveBar = true
                            local bar = AQT:GetBar(barIdx)
                            bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                            
                            local barHeight = ASSETS.barHeight
                            if isWorldQuest and wqDB and wqDB.barHeight then
                                barHeight = wqDB.barHeight
                            elseif not isWorldQuest and questDB and questDB.barHeight then
                                barHeight = questDB.barHeight
                            end
                            bar:SetSize(width - 20, barHeight)
                            
                            bar:SetMinMaxValues(0, 1) -- Ensure normalized scale
                            bar:SetValue(obj.numFulfilled / obj.numRequired)
                            bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b)
                            bar:Show()
                            
                            -- Fixed spacing after bar
                            yOffset = yOffset - 10
                            barIdx = barIdx + 1
                        end
                    end
                end
            end

            -- Bonus Objective Bar (World Quests / Bonus Objectives)
            local progress = nil
            -- Only check for progress bar if we haven't already displayed objectives
            -- or if it's explicitly a Task/Bonus Objective
            if isWorldQuest or (C_TaskQuest and C_TaskQuest.IsActive and C_TaskQuest.IsActive(qID)) then
                if C_TaskQuest and C_TaskQuest.GetQuestProgressBarInfo then
                    progress = C_TaskQuest.GetQuestProgressBarInfo(qID)
                end
                
                if not progress and GetQuestProgressBarPercent then
                     progress = GetQuestProgressBarPercent(qID)
                end

                if not isComplete and progress then
                    -- Check if we already have a bar for this quest in objectives
                    -- If so, don't duplicate it unless it's a specific bonus bar
                    local alreadyHasBar = objectivesHaveBar
                    
                    if not alreadyHasBar then
                        local pLine = AQT:GetLine(lineIdx)
                        pLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                        pLine:SetWidth(width - 20)
                        
                        local objFontSize = ASSETS.fontTextSize
                        if isWorldQuest and wqDB and wqDB.objSize then
                            objFontSize = wqDB.objSize
                        elseif not isWorldQuest and questDB and questDB.objSize then
                            objFontSize = questDB.objSize
                        end
                        pLine.text:SetFont(ASSETS.font, objFontSize, "OUTLINE")
                        
                        SafelySetText(pLine.text, string.format(L["Progress: %d%%"], progress))
                        pLine:Show()
                        yOffset = yOffset - 12
                        lineIdx = lineIdx + 1

                        local bar = AQT:GetBar(barIdx)
                        
                        local barHeight = ASSETS.barHeight
                        if isWorldQuest and wqDB and wqDB.barHeight then
                            barHeight = wqDB.barHeight
                        end
                        
                        bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                        bar:SetSize(width - 20, barHeight)
                        bar:SetValue(progress / 100)
                        bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b)
                        bar:Show()
                        local spacing = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.barSpacing) or 8
                        yOffset = yOffset - spacing
                        barIdx = barIdx + 1
                    end
                end
            end
            yOffset = yOffset - 6
        end
    end
    return yOffset, lineIdx, barIdx, itemIdx
end

-- 3. ACHIEVEMENTS
local function RenderAchievements(startY, lineIdx)
    local yOffset = startY
    local tracked = GetTrackedAchievements and { GetTrackedAchievements() } or {}
    if #tracked == 0 then return yOffset, lineIdx end

    local header = AQT:GetLine(lineIdx)
    header.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
    header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    header.text:SetTextColor(ASSETS.colors.header.r, ASSETS.colors.header.g, ASSETS.colors.header.b)
    SafelySetText(header.text, L["Achievements"])
    header:Show()
    yOffset = yOffset - 16
    lineIdx = lineIdx + 1

    for _, achID in ipairs(tracked) do
        local id, name, _, completed = GetAchievementInfo(achID)
        if not completed and id then
            local line = AQT:GetLine(lineIdx)
            line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
            line.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
            line.text:SetTextColor(ASSETS.colors.achievement.r, ASSETS.colors.achievement.g, ASSETS.colors.achievement.b)
            SafelySetText(line.text, name)
            
            line:EnableMouse(true)
            line:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetAchievementByID(achID)
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function() GameTooltip:Hide() end)
            line:SetScript("OnClick", function()
                if not AchievementFrame then AchievementFrame_LoadUI() end
                AchievementFrame_SelectAchievement(achID)
            end)
            
            line:Show()
            yOffset = yOffset - 14
            lineIdx = lineIdx + 1
            
            -- Detailed Criteria
            local numCriteria = GetAchievementNumCriteria(achID)
            for i = 1, numCriteria do
                local cName, _, cComp, cQty, cReq = GetAchievementCriteriaInfo(achID, i)
                if not cComp and (bit.band(select(7, GetAchievementCriteriaInfo(achID, i)), 1) ~= 1) then -- Skip hidden
                    local cLine = AQT:GetLine(lineIdx)
                    cLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
                    cLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                    
                    local cText = cName
                    if cReq and cReq > 1 then
                        cText = string.format("%s: %d/%d", cName, cQty, cReq)
                    end
                    SafelySetText(cLine.text, cText)
                    cLine.text:SetTextColor(0.8, 0.8, 0.8)
                    cLine:Show()
                    yOffset = yOffset - 12
                    lineIdx = lineIdx + 1
                end
            end
            yOffset = yOffset - 4
        end
    end
    return yOffset, lineIdx
end

local function RenderMock(startY, lineIdx, barIdx)
    local width = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.width) or 260
    local yOffset = startY
    local barSpacing = (AscensionQuestTrackerDB and AscensionQuestTrackerDB.barSpacing) or 8
    
    -- Get Configs
    local scenarioDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.scenario or {}
    local wqDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.worldQuest or {}
    local focusDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.focused or {}
    local questDB = AscensionQuestTrackerDB and AscensionQuestTrackerDB.quest or {}
    
    -- WQ Values
    local wqTitleSize = wqDB.titleSize or ASSETS.fontHeaderSize
    local wqDescSize = wqDB.descSize or ASSETS.fontTextSize
    local wqObjSize = wqDB.objSize or ASSETS.fontTextSize
    local wqBarHeight = wqDB.barHeight or ASSETS.barHeight
    local wqTitleColor = wqDB.titleColor or ASSETS.colors.wq
    local wqBarColor = wqDB.barColor or ASSETS.colors.wq
    
    -- Focus Values
    local focusTitleColor = focusDB.titleColor or ASSETS.colors.active
    local focusBarColor = focusDB.barColor or ASSETS.colors.quest

    -- Quest Values (Normal)
    local questTitleSize = questDB.titleSize or ASSETS.fontHeaderSize
    local questDescSize = questDB.descSize or ASSETS.fontTextSize
    local questObjSize = questDB.objSize or ASSETS.fontTextSize
    local questBarHeight = questDB.barHeight or ASSETS.barHeight
    local questTitleColor = questDB.titleColor or ASSETS.colors.quest
    local questBarColor = questDB.barColor or ASSETS.colors.quest

    -- MOCK SCENARIO
    -- Use config values
    local titleSize = scenarioDB.titleSize or ASSETS.fontHeaderSize
    local descSize = scenarioDB.descSize or ASSETS.fontTextSize
    local objSize = scenarioDB.objSize or ASSETS.fontTextSize
    local barHeight = scenarioDB.barHeight or ASSETS.barHeight
    local barColor = scenarioDB.barColor or ASSETS.colors.quest

    -- Header
    local header = AQT:GetLine(lineIdx)
    header.text:SetFont(ASSETS.font, titleSize + 2, "OUTLINE")
    header:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    header:SetWidth(width - 20)
    SafelySetText(header.text, L["Test Dungeon (Mythic)"])
    header:Show()
    yOffset = yOffset - 16
    lineIdx = lineIdx + 1
    
    -- Stage
    local sLine = AQT:GetLine(lineIdx)
    sLine.text:SetFont(ASSETS.font, descSize, "OUTLINE")
    sLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    sLine:SetWidth(width - 20)
    sLine.text:SetTextColor(1, 0.8, 0)
    SafelySetText(sLine.text, L["Stage 2: The Test"])
    sLine:Show()
    yOffset = yOffset - 14
    lineIdx = lineIdx + 1

    -- Boss 1 (Done)
    local b1Line = AQT:GetLine(lineIdx)
    b1Line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    b1Line:SetWidth(width - 20)
    b1Line.text:SetFont(ASSETS.font, objSize, "OUTLINE")
    b1Line.text:SetTextColor(ASSETS.colors.complete.r, ASSETS.colors.complete.g, ASSETS.colors.complete.b)
    SafelySetText(b1Line.text, "- " .. L["Boss 1 (Done)"])
    b1Line:Show()
    yOffset = yOffset - 14
    lineIdx = lineIdx + 1

    -- Boss 2 (Alive)
    local b2Line = AQT:GetLine(lineIdx)
    b2Line:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    b2Line:SetWidth(width - 20)
    b2Line.text:SetFont(ASSETS.font, objSize, "OUTLINE")
    SafelySetText(b2Line.text, "- " .. L["Boss 2 (Alive)"])
    b2Line:Show()
    yOffset = yOffset - 14
    lineIdx = lineIdx + 1
    
    -- Objective with Bar
    local pLine = AQT:GetLine(lineIdx)
    pLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    pLine:SetWidth(width - 20)
    pLine.text:SetFont(ASSETS.font, objSize, "OUTLINE")
    SafelySetText(pLine.text, L["Enemies Defeated (50%)"])
    pLine:Show()
    
    yOffset = yOffset - barSpacing -- Configurable Spacing
    
    local bar = AQT:GetBar(barIdx)
    bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    bar:SetSize(width - 20, barHeight)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(50)
    bar:SetStatusBarColor(barColor.r, barColor.g, barColor.b, barColor.a or 1)
    bar:Show()
    yOffset = yOffset - 10
    barIdx = barIdx + 1
    lineIdx = lineIdx + 1

    -- MOCK WORLD QUEST
    yOffset = yOffset - 15

    -- Zone Header
    local zLineWQ = AQT:GetLine(lineIdx)
    zLineWQ.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize - 1, "OUTLINE")
    zLineWQ:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    zLineWQ:SetWidth(width - 20)
    zLineWQ.text:SetTextColor(ASSETS.colors.zone.r, ASSETS.colors.zone.g, ASSETS.colors.zone.b)
    SafelySetText(zLineWQ.text, "Azsuna")
    zLineWQ:Show()
    yOffset = yOffset - 14
    lineIdx = lineIdx + 1

    -- WQ Title
    local wqTitle = AQT:GetLine(lineIdx)
    wqTitle:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    wqTitle:SetWidth(width - 20)
    wqTitle.text:SetFont(ASSETS.font, wqTitleSize, "OUTLINE")
    wqTitle.text:SetTextColor(wqTitleColor.r, wqTitleColor.g, wqTitleColor.b)
    
    -- Simulate Distance and Time: [1.2km] [23h] Title
    local wqText = L["Test World Quest"]
    wqText = "[23h] " .. wqText
    wqText = "[1.2km] " .. wqText
    
    SafelySetText(wqTitle.text, wqText)
    wqTitle:Show()
    yOffset = yOffset - 15
    lineIdx = lineIdx + 1
    
    -- WQ Objective with Bar
    local wqObj = AQT:GetLine(lineIdx)
    wqObj:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    wqObj:SetWidth(width - 20)
    wqObj.text:SetFont(ASSETS.font, wqObjSize, "OUTLINE")
    SafelySetText(wqObj.text, L["Rare Mob Slain"] .. " (50%)")
    wqObj:Show()
    
    yOffset = yOffset - barSpacing -- Configurable Spacing
    
    local wqBar = AQT:GetBar(barIdx)
    wqBar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    wqBar:SetSize(width - 20, wqBarHeight) -- Configurable Height
    wqBar:SetMinMaxValues(0, 100)
    wqBar:SetValue(50)
    wqBar:SetStatusBarColor(wqBarColor.r, wqBarColor.g, wqBarColor.b, 1)
    wqBar:Show()
    yOffset = yOffset - 10
    barIdx = barIdx + 1
    lineIdx = lineIdx + 1

    -- MOCK QUESTS
    yOffset = yOffset - 10
    
    -- Zone Header
    local zLine = AQT:GetLine(lineIdx)
    zLine.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize - 1, "OUTLINE")
    zLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    zLine:SetWidth(width - 20)
    zLine.text:SetTextColor(ASSETS.colors.zone.r, ASSETS.colors.zone.g, ASSETS.colors.zone.b)
    SafelySetText(zLine.text, "Elwynn Forest")
    zLine:Show()
    yOffset = yOffset - 14
    lineIdx = lineIdx + 1
    
    -- Quest Title
    local qTitle = AQT:GetLine(lineIdx)
    qTitle:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    qTitle:SetWidth(width - 20)
    qTitle.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
    qTitle.text:SetTextColor(focusTitleColor.r, focusTitleColor.g, focusTitleColor.b)
    SafelySetText(qTitle.text, L["Test Quest 1"] .. " (Focused)")
    qTitle:Show()
    yOffset = yOffset - 15
    lineIdx = lineIdx + 1
    
    -- Quest Objective
    local oLine = AQT:GetLine(lineIdx)
    oLine:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    oLine:SetWidth(width - 20)
    oLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
    SafelySetText(oLine.text, L["Items Collected: 3/12"])
    oLine:Show()
    
    yOffset = yOffset - barSpacing -- Configurable Spacing
    
    local q1Bar = AQT:GetBar(barIdx)
    q1Bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    q1Bar:SetSize(width - 20, ASSETS.barHeight)
    q1Bar:SetMinMaxValues(0, 100)
    q1Bar:SetValue(33)
    q1Bar:SetStatusBarColor(focusBarColor.r, focusBarColor.g, focusBarColor.b, 1)
    q1Bar:Show()
    barIdx = barIdx + 1
    yOffset = yOffset - 10
    
    lineIdx = lineIdx + 1

    -- Quest 2 (Normal - Uses Quest Configs)
    local qTitle2 = AQT:GetLine(lineIdx)
    qTitle2:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    qTitle2:SetWidth(width - 20)
    qTitle2.text:SetFont(ASSETS.font, questTitleSize, "OUTLINE")
    qTitle2.text:SetTextColor(questTitleColor.r, questTitleColor.g, questTitleColor.b)
    SafelySetText(qTitle2.text, L["Test Quest 2"])
    
    qTitle2:Show()
    yOffset = yOffset - 15
    lineIdx = lineIdx + 1

    -- Quest 2 Objective
    local oLine2 = AQT:GetLine(lineIdx)
    oLine2:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    oLine2:SetWidth(width - 20)
    oLine2.text:SetFont(ASSETS.font, questObjSize, "OUTLINE")
    SafelySetText(oLine2.text, L["Find the Key: 0/1"] .. " (80%)")
    oLine2:Show()
    yOffset = yOffset - barSpacing
    
    local q2Bar = AQT:GetBar(barIdx)
    q2Bar:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    q2Bar:SetSize(width - 20, questBarHeight)
    q2Bar:SetMinMaxValues(0, 100)
    q2Bar:SetValue(80)
    q2Bar:SetStatusBarColor(questBarColor.r, questBarColor.g, questBarColor.b, 1)
    q2Bar:Show()
    barIdx = barIdx + 1
    
    yOffset = yOffset - 12
    lineIdx = lineIdx + 1
    
    -- Quest 3 (Completed)
    local qTitle3 = AQT:GetLine(lineIdx)
    qTitle3:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    qTitle3:SetWidth(width - 20)
    qTitle3.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
    qTitle3.text:SetTextColor(ASSETS.colors.complete.r, ASSETS.colors.complete.g, ASSETS.colors.complete.b)
    SafelySetText(qTitle3.text, L["Test Quest 3"] .. " " .. L["(Ready)"])
    qTitle3:Show()
    yOffset = yOffset - 15
    lineIdx = lineIdx + 1

    -- Quest 3 Objective
    local oLine3 = AQT:GetLine(lineIdx)
    oLine3:SetPoint("TOPRIGHT", AQT, "TOPRIGHT", -ASSETS.padding, yOffset)
    oLine3:SetWidth(width - 20)
    oLine3.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
    oLine3.text:SetTextColor(ASSETS.colors.complete.r, ASSETS.colors.complete.g, ASSETS.colors.complete.b)
    SafelySetText(oLine3.text, L["Objective Complete"])
    oLine3:Show()
    yOffset = yOffset - 12
    lineIdx = lineIdx + 1
    
    return yOffset, lineIdx, barIdx
end

--------------------------------------------------------------------------------
-- UPDATE LOGIC
--------------------------------------------------------------------------------

function AQT:FullUpdate()
    for _, l in ipairs(AQT.lines) do l:Hide() end
    for _, b in ipairs(AQT.bars) do b:Hide() end
    if not InCombatLockdown() then
        for _, itm in ipairs(AQT.itemButtons) do itm:Hide() end
    end
    
    local y = -ASSETS.padding
    local lIdx = 1
    local bIdx = 1
    
    if AscensionQuestTrackerDB and AscensionQuestTrackerDB.testMode then
        y, lIdx, bIdx = RenderMock(y, lIdx, bIdx)
    else
        y, lIdx, bIdx = RenderScenario(y, lIdx, bIdx)
        local itemIdx = 1
        y, lIdx, bIdx, itemIdx = RenderQuests(y, lIdx, bIdx, itemIdx)
        RenderAchievements(y, lIdx)
    end
    
    local h = math.abs(y) + ASSETS.padding
    if not InCombatLockdown() then
        AQT:SetHeight(h < 50 and 50 or h)
    end
end

--------------------------------------------------------------------------------
-- BLIZZARD TRACKER VISIBILITY MANAGER
--------------------------------------------------------------------------------
-- Identify the correct tracker frame (Retail vs Classic/WotLK)
AQT.BlizzTracker = nil

function AQT:InitializeBlizzardHider()
    if not AQT.BlizzTracker then
        AQT.BlizzTracker = ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame
    end
    if not AQT.BlizzTracker then return end
    
    -- Hook OnShow to enforce hiding if enabled
    -- This prevents the tracker from reappearing when Blizzard UI code calls Show()
    if not AQT.BlizzTracker.isHooked then
        AQT.BlizzTracker:HookScript("OnShow", function(self)
            if AscensionQuestTrackerDB.hideBlizzardTracker then
                self:Hide()
            end
        end)
        AQT.BlizzTracker.isHooked = true
    end
end

function AQT:UpdateBlizzardTrackerVisibility()
    -- Ensure tracker is identified
    if not AQT.BlizzTracker then
        AQT.BlizzTracker = ObjectiveTrackerFrame or WatchFrame or QuestWatchFrame
    end
    if not AQT.BlizzTracker then return end
    
    -- Initialize the hook if not already done
    AQT:InitializeBlizzardHider()
    
    if AscensionQuestTrackerDB.hideBlizzardTracker then
        AQT.BlizzTracker:Hide()
    else
        AQT.BlizzTracker:Show()
    end
end

local function Initialize()
    if not AscensionQuestTrackerDB then 
        AscensionQuestTrackerDB = { 
            scale = 1, 
            width = 260, 
            hideOnBoss = true, 
            locked = false, 
            hideBlizzardTracker = true,
            showAllZoneHeaders = false
        } 
    end
    
    if AscensionQuestTrackerDB.showAllZoneHeaders == nil then
        AscensionQuestTrackerDB.showAllZoneHeaders = false
    end
    
    local db = AscensionQuestTrackerDB
    AQT:SetSize(db.width or 260, 100)
    AQT:SetScale(db.scale or 1)
    
    -- Apply visibility settings
    AQT:UpdateBlizzardTrackerVisibility()
    
    if db.position then
        AQT:ClearAllPoints()
        AQT:SetPoint(db.position.point, UIParent, db.position.relativePoint, db.position.x, db.position.y)
    else
        AQT:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    end

    AQT:SetMovable(true)
    AQT:EnableMouse(not db.locked) 
    AQT:RegisterForDrag("LeftButton")
    
    AQT:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        AscensionQuestTrackerDB.position = { point = point, relativePoint = rel, x = x, y = y }
    end)
    
    AQT:SetScript("OnDragStart", function(self)
        if not AscensionQuestTrackerDB.locked then self:StartMoving() end
    end)
    
    AQT:FullUpdate()
end

AQT:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(0.1, Initialize)
    elseif event == "ENCOUNTER_START" then 
        AQT.inBossCombat = true
        self.isDirty = true
    elseif event == "ENCOUNTER_END" then 
        AQT.inBossCombat = false
        self.isDirty = true
    elseif event == "QUEST_TURNED_IN" then
        if SOUNDKIT and SOUNDKIT.UI_QUEST_LOG_QUEST_ABANDONED then
            SafePlaySound(SOUNDKIT.UI_QUEST_LOG_QUEST_ABANDONED) -- Simple feedback
        end
        self.isDirty = true
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        self.isDirty = true
        -- Auto SuperTrack closest quest in new zone
        C_Timer.After(2, function()
             if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID and #pooled_quests > 0 then
                  local bestID, bestDist = nil, 999999
                  for _, q in ipairs(pooled_quests) do
                      if q.distValue and q.distValue > 0 and q.distValue < bestDist then
                          bestDist = q.distValue
                          bestID = q.id
                      end
                  end
                  if bestID then C_SuperTrack.SetSuperTrackedQuestID(bestID) end
             end
        end)
    else
        self.isDirty = true
    end
end)

AQT:RegisterEvent("PLAYER_LOGIN")
AQT:RegisterEvent("QUEST_LOG_UPDATE")
AQT:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
AQT:RegisterEvent("SUPER_TRACKING_CHANGED")
AQT:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
AQT:RegisterEvent("SCENARIO_UPDATE")
AQT:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
AQT:RegisterEvent("SCENARIO_POI_UPDATE")
AQT:RegisterEvent("CRITERIA_COMPLETE")
AQT:RegisterEvent("SCENARIO_COMPLETED")
AQT:RegisterEvent("CHALLENGE_MODE_START")
AQT:RegisterEvent("ENCOUNTER_START")
AQT:RegisterEvent("ENCOUNTER_END")
AQT:RegisterEvent("ZONE_CHANGED_NEW_AREA")
AQT:RegisterEvent("QUEST_TURNED_IN")
AQT:RegisterEvent("PLAYER_REGEN_ENABLED")
-- World Quest Events
AQT:RegisterEvent("QUEST_ACCEPTED")
AQT:RegisterEvent("QUEST_DATA_LOAD_RESULT")
AQT:RegisterEvent("QUEST_REMOVED")
AQT:RegisterEvent("UNIT_QUEST_LOG_CHANGED")

--------------------------------------------------------------------------------
-- ON UPDATE HOOK
--------------------------------------------------------------------------------
local t = 0
AQT.isDirty = true -- Update on load
AQT:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    
    -- Event-Driven Update (Throttled)
    if self.isDirty then
        AQT:FullUpdate()
        self.isDirty = false
        t = 0
        return
    end
    
    -- Periodic Update (Distances & Timers)
    if t > 1.0 then 
        AQT:FullUpdate()
        t = 0
    end
end)
