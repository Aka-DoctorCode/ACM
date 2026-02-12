-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Widgets.lua
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

-- Constants for Widget Types
-- Referenced from Design Document (Source 66)
local WIDGET_CAPTURE_BAR = 1        -- PvP / Control
local WIDGET_STATUS_BAR = 2         -- General Progress
local WIDGET_SCENARIO_HEADER = 20   -- Scenario Timers
local WIDGET_DELVES_HEADER = 29     -- Delves Specifics

--------------------------------------------------------------------------------
-- WIDGET RENDERING LOGIC
--------------------------------------------------------------------------------

function AQT:RenderWidgets(y, lineIndex, barIndex)
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
        if wType == WIDGET_CAPTURE_BAR or wType == WIDGET_STATUS_BAR or wType == WIDGET_DELVES_HEADER then
            local info = C_UIWidgetManager.GetDoubleStatusBarWidgetVisualizationInfo(wID)
            if info and info.shownState == 1 then -- 1 means "Shown"
                -- Header Line
                local line = self:GetLine(lineIndex)
                line:Show()
                line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, y) 
                AQT.SafelySetText(line.text, info.text or "Objective")
                y = y - 16
                lineIndex = lineIndex + 1

                -- The Bar
                local bar = self:GetBar(barIndex)
                bar:Show()
                bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, y)
                bar:SetSize(ASSETS.width - 20, 14)
                
                -- Calculate percentage (Value / Range)
                local minVal, maxVal, curVal = info.min, info.max, info.value
                local range = maxVal - minVal
                local percent = 0
                if range > 0 then
                    percent = (curVal - minVal) / range
                end
                bar:SetValue(percent)
                
                y = y - 18
                barIndex = barIndex + 1
            end

        -- Render: Standard Status Bar (e.g., Delves Power / Bonus Events)
        elseif wType == WIDGET_STATUS_BAR then
            local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(wID)
            if info and info.shownState == 1 then
                -- Header Line
                local line = self:GetLine(lineIndex)
                line:Show()
                line:SetPoint("TOPLEFT", self, "TOPLEFT", 10, y)
                AQT.SafelySetText(line.text, info.text or "Event")
                y = y - 16
                lineIndex = lineIndex + 1

                -- The Bar
                local bar = self:GetBar(barIndex)
                bar:Show()
                bar:SetPoint("TOPLEFT", self, "TOPLEFT", 10, y)
                bar:SetSize(ASSETS.width - 20, 14)

                local minVal, maxVal, curVal = info.barMin, info.barMax, info.barValue
                local range = maxVal - minVal
                local percent = 0
                if range > 0 then
                    percent = (curVal - minVal) / range
                end
                bar:SetValue(percent)

                y = y - 18
                barIndex = barIndex + 1
            end
            
        -- Render: Delves & Scenario Special Headers (Types 29 and 20)
        -- These often use the same data structure as StatusBar or require Text handling
        elseif wType == WIDGET_DELVES_HEADER or wType == WIDGET_SCENARIO_HEADER then
            -- Attempt to get generic visualization info
            local info = C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo(wID)
            if info and info.shownState == 1 then
                local line = self:GetLine(lineIndex)
                line:Show()
                line:SetPoint("TOPLEFT", self, "TOPLEFT", 10, y)
                -- Delves often have "text" property for the objective name
                AQT.SafelySetText(line.text, info.text or "Scenario Objective")
                y = y - 16
                lineIndex = lineIndex + 1
                
                -- Only render bar if values exist
                if info.barMax and info.barMax > 0 then
                    local bar = self:GetBar(barIndex)
                    bar:Show()
                    bar:SetPoint("TOPLEFT", self, "TOPLEFT", 10, y)
                    bar:SetSize(ASSETS.width - 20, 14)
                    
                    local minVal, maxVal, curVal = info.barMin, info.barMax, info.barValue
                    local range = maxVal - minVal
                    local percent = 0
                    if range > 0 then percent = (curVal - minVal) / range end
                    bar:SetValue(percent)
                    
                    y = y - 18
                    barIndex = barIndex + 1
                end
            end
        end
    end

    return y, lineIndex, barIndex
end
