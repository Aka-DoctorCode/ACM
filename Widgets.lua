-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Widgets.lua
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

-- Constants for Widget Types
local WIDGET_CAPTURE_BAR = 1        
local WIDGET_STATUS_BAR = 2         
local WIDGET_SCENARIO_HEADER = 20   
local WIDGET_DELVES_HEADER = 29     

-- Object Pools
AQT.lines = {}
AQT.bars = {}
AQT.items = {}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

function AQT.SafelySetText(fontString, text)
    if not fontString then return end
    if not text or text == "" then 
        fontString:SetText("")
        return 
    end
    fontString:SetText(text)
end

function AQT:SafeCall(func)
    local status, err = pcall(func)
    if not status then
        geterrorhandler()(err)
    end
end

function AQT:FormatTime(seconds)
    if not seconds then return "0:00" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return string.format("%d:%02d", m, s)
end

--------------------------------------------------------------------------------
-- WIDGET POOLING SYSTEM
--------------------------------------------------------------------------------

function AQT:CreateContainer()
    if self.Container then return end

    local f = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)
    f:SetSize(300, 600)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -50, 0)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)

    -- Background (Visual helper for moving)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(true)
    bg:SetColorTexture(0.1, 0.1, 0.1, 0)
    f.bg = bg
    
    -- Drag Logic
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not AQT.db.profile.locked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    end)

    -- Scroll Frame
    local scrollFrame = CreateFrame("ScrollFrame", "$parentScrollFrame", f)
    scrollFrame:SetPoint("TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    
    -- Enable Mouse Wheel Scrolling
    local function OnMouseWheel(self, delta)
        local scrollChild = scrollFrame:GetScrollChild()
        if not scrollChild then return end

        local current = scrollFrame:GetVerticalScroll()
        local range = scrollChild:GetHeight() - scrollFrame:GetHeight()
        if range < 0 then range = 0 end
        
        local step = 30 -- Scroll speed
        local new = current - (delta * step)
        
        if new < 0 then new = 0 end
        if new > range then new = range end
        
        scrollFrame:SetVerticalScroll(new)
    end

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", OnMouseWheel)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", OnMouseWheel)

    local content = CreateFrame("Frame", "$parentContent", scrollFrame)
    content:SetSize(300, 600)
    scrollFrame:SetScrollChild(content)

    self.Container = f
    self.ScrollFrame = scrollFrame
    self.Content = content
    
    -- Apply settings
    f:SetScale(self.db.profile.scale or 1)
    if self.db.profile.locked then f:EnableMouse(false) end
end

function AQT:GetLine(index)
    if not self.lines[index] then
        local line = CreateFrame("Button", nil, self.Content)
        line:SetHeight(20)
        -- Drag handlers
        line:RegisterForDrag("LeftButton")
        line:SetScript("OnDragStart", function()
            if not AQT.db.profile.locked and AQT.Container then AQT.Container:StartMoving() end
        end)
        line:SetScript("OnDragStop", function()
            if AQT.Container then AQT.Container:StopMovingOrSizing() end
        end)

        -- Text creation
        line.text = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line.text:SetPoint("TOPLEFT", 20, 0)
        line.text:SetPoint("RIGHT", -5, 0)
        line.text:SetJustifyH("LEFT")
        line.text:SetWordWrap(true)
        
        -- Icon creation
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetPoint("TOPLEFT", 0, -2)
        line.icon:SetSize(12, 12)
        
        self.lines[index] = line
    end
    
    -- Reset state & UPDATE WIDTH
    local l = self.lines[index]
    l:SetWidth(self.db.profile.width or 260)
    
    l:ClearAllPoints()
    l:SetHeight(20) -- Default height, will be adjusted dynamically
    l:Hide()
    l.text:SetText("")
    l:EnableMouse(false)
    l:SetScript("OnClick", nil)
    l:SetScript("OnEnter", nil)
    l:SetScript("OnLeave", nil)
    l.icon:Hide()
    
    return l
end

function AQT:GetBar(index)
    if not self.bars[index] then
        local bar = CreateFrame("StatusBar", nil, self.Content)
        bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        bar:GetStatusBarTexture():SetHorizTile(false)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        
        -- Background
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(true)
        bg:SetColorTexture(0, 0, 0, 0.5)
        bar.bg = bg
        
        self.bars[index] = bar
    end
    
    local b = self.bars[index]
    b:ClearAllPoints()
    b:Hide()
    b:SetValue(0)
    
    return b
end

function AQT:GetItemButton(index)
    if not self.items[index] then
        local btn = CreateFrame("Button", "AQTItemButton"..index, self.Content, "SecureActionButtonTemplate")
        btn:SetSize(20, 20)
        
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetAllPoints(true)
        
        btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        btn.count:SetPoint("BOTTOMRIGHT", -2, 2)
        
        self.items[index] = btn
    end
    
    local i = self.items[index]
    i:ClearAllPoints()
    i:Hide()
    i:SetAttribute("type", nil)
    i:SetAttribute("item", nil)
    
    return i
end

--------------------------------------------------------------------------------
-- MAIN UPDATE LOOP
--------------------------------------------------------------------------------

function AQT:UpdateLayout()
    -- Ensure container exists
    if not self.Container then 
        self:CreateContainer() 
    end
    
    -- Check visibility settings
    if self.db.profile.hideOnBoss and IsEncounterInProgress() then
        self.Container:Hide()
        return
    end
    
    local currentWidth = self.db.profile.width or 260
    
    self.Container:Show()
    self.Container:SetScale(self.db.profile.scale or 1)
    self.Container:SetWidth(currentWidth)
    self.Content:SetWidth(currentWidth)

    -- Update Locked State and Background Visibility
    if self.db.profile.locked then
        self.Container:EnableMouse(false)
        if self.Container.bg then self.Container.bg:Hide() end
    else
        self.Container:EnableMouse(true)
        if self.Container.bg then self.Container.bg:Show() end
    end
    
    -- Reset counters
    local lineIdx = 1
    local barIdx = 1
    local itemIdx = 1
    local yOffset = -10
    
    local padding = 10 
    -- Ensure Theme ASSETS are loaded (fallback if nil)
    if not ns.ASSETS then ns.ASSETS = self.Themes and self.Themes.Default or {} end

    -- Hide all existing
    for _, l in pairs(self.lines) do l:Hide() end
    for _, b in pairs(self.bars) do b:Hide() end
    for _, i in pairs(self.items) do i:Hide() end

    -- Render Sequence
    
    -- 1. Scenarios / Dungeons
    if self.RenderScenario then
        yOffset, lineIdx, barIdx = self:RenderScenario(yOffset, lineIdx, barIdx, self.db.profile.styles.scenarios)
    end
    
    -- 2. PvP / Scenario Widgets
    if self.RenderWidgets then
        yOffset, lineIdx, barIdx = self:RenderWidgets(yOffset, lineIdx, barIdx)
    end

    -- 3. Quests (Campaign + Normal)  <-- MOVED UP: To be before World Quests
    if self.RenderQuests then
        yOffset, lineIdx, barIdx, itemIdx = self:RenderQuests(yOffset, lineIdx, barIdx, itemIdx, self.db.profile.styles.quests)
    end
    
    -- 4. World Quests  <-- MOVED DOWN: To be after Quests
    if self.RenderWorldQuests then
        yOffset, lineIdx, barIdx, itemIdx = self:RenderWorldQuests(yOffset, lineIdx, barIdx, itemIdx, self.db.profile.styles.worldQuests)
    end
    
    -- 5. Achievements
    if self.RenderAchievements then
        yOffset, lineIdx = self:RenderAchievements(yOffset, lineIdx, self.db.profile.styles.achievements)
    end
    
    -- Adjust content height
    local totalHeight = math.abs(yOffset) + 20
    self.Content:SetHeight(totalHeight)
    self.Container:SetHeight(math.min(totalHeight, self.db.profile.maxHeight or 600))
end


--------------------------------------------------------------------------------
-- WIDGET RENDERING LOGIC
--------------------------------------------------------------------------------

function AQT:RenderWidgets(y, lineIndex, barIndex)
    -- HIDE IF TEST MODE IS ON
    if self.db.profile.testMode then return y, lineIndex, barIndex end

    local ASSETS = ns.ASSETS
    -- 1. Get the Active Widget Set for the "Top Center" (Standard for Objectives)
    local uiWidgetSetID = C_UIWidgetManager.GetTopCenterWidgetSetID()
    if not uiWidgetSetID then return y, lineIndex, barIndex end

    -- 2. Retrieve all widgets in this set
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(uiWidgetSetID)
    
    -- 3. Sort widgets by order index to match Blizzard's layout
    table.sort(widgets, function(a, b)
        return (a.orderIndex or 0) < (b.orderIndex or 0)
    end)

    for _, widgetInfo in ipairs(widgets) do
        local wID = widgetInfo.widgetID
        local wType = widgetInfo.widgetType
        
        -- Render: Double Status Bar (e.g., PvP Capture Points)
        if wType == WIDGET_CAPTURE_BAR then
            local info = C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo(wID)
            if info and info.shownState == 1 then -- 1 means "Shown"
                -- Header Line
                local line = self:GetLine(lineIndex)
                line:Show()
                line:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -10, y) 
                self.SafelySetText(line.text, info.text or "Objective")
                
                -- Dynamic Height Calculation
                local textHeight = line.text:GetStringHeight()
                line:SetHeight(math.max(20, textHeight))
                y = y - textHeight - 2 -- Push down by exact text height + padding
                lineIndex = lineIndex + 1

                -- The Bar
                local bar = self:GetBar(barIndex)
                bar:Show()
                bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -10, y)
                bar:SetSize((self.db.profile.width or 260) - 20, 14)
                
                -- Calculate percentage (Value / Range)
                local minVal, maxVal, curVal = info.min, info.max, info.value
                local range = maxVal - minVal
                local percent = 0
                if range > 0 then
                    percent = (curVal - minVal) / range
                end
                bar:SetValue(percent)
                
                y = y - 14 - 4 -- Push down by bar height + padding
                barIndex = barIndex + 1
            end

        -- Render: Standard Status Bar (e.g., Delves Power / Bonus Events)
        elseif wType == WIDGET_STATUS_BAR then
            local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(wID)
            if info and info.shownState == 1 then
                -- Header Line
                local line = self:GetLine(lineIndex)
                line:Show()
                line:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 10, y)
                self.SafelySetText(line.text, info.text or "Event")
                
                -- Dynamic Height Calculation
                local textHeight = line.text:GetStringHeight()
                line:SetHeight(math.max(20, textHeight))
                y = y - textHeight - 2
                lineIndex = lineIndex + 1

                -- The Bar
                local bar = self:GetBar(barIndex)
                bar:Show()
                bar:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 10, y)
                bar:SetSize((self.db.profile.width or 260) - 20, 14)

                local minVal, maxVal, curVal = info.barMin, info.barMax, info.barValue
                local range = maxVal - minVal
                local percent = 0
                if range > 0 then
                    percent = (curVal - minVal) / range
                end
                bar:SetValue(percent)

                y = y - 14 - 4
                barIndex = barIndex + 1
            end
            
        -- Render: Delves & Scenario Special Headers (Types 29 and 20)
        elseif wType == WIDGET_DELVES_HEADER or wType == WIDGET_SCENARIO_HEADER then
            local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(wID)
            if info and info.shownState == 1 then
                local line = self:GetLine(lineIndex)
                line:Show()
                line:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 10, y)
                self.SafelySetText(line.text, info.text or "Scenario Objective")
                
                -- Dynamic Height Calculation
                local textHeight = line.text:GetStringHeight()
                line:SetHeight(math.max(20, textHeight))
                y = y - textHeight - 2
                lineIndex = lineIndex + 1
                
                if info.barMax and info.barMax > 0 then
                    local bar = self:GetBar(barIndex)
                    bar:Show()
                    bar:SetPoint("TOPLEFT", self.Content, "TOPLEFT", 10, y)
                    bar:SetSize((self.db.profile.width or 260) - 20, 14)
                    
                    local minVal, maxVal, curVal = info.barMin, info.barMax, info.barValue
                    local range = maxVal - minVal
                    local percent = 0
                    if range > 0 then percent = (curVal - minVal) / range end
                    bar:SetValue(percent)
                    
                    y = y - 14 - 4
                    barIndex = barIndex + 1
                end
            end
        end
    end

    return y, lineIndex, barIndex
end