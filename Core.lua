-------------------------------------------------------------------------------
-- Project: AscensionQuestTracker
-- Author: Aka-DoctorCode 
-- File: Core.lua
-- Version: 05
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local addonName, ns = ...
-- Initialize AceAddon
local AQT = LibStub("AceAddon-3.0"):NewAddon("AscensionQuestTracker", "AceEvent-3.0", "AceConsole-3.0")
ns.AQT = AQT 

local defaults = {
    profile = {
        position = { point = "RIGHT", relativePoint = "RIGHT", x = -50, y = 0 },
        scale = 1.0,
        hideOnBoss = true,
        autoSuperTrack = false,
        locked = false,
        maxHeight = 600,
        width = 260,
        fontHeaderSize = 13,
        fontTextSize = 10,
        lineSpacing = 6,
        sectionSpacing = 15
    }
}

function AQT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionQuestTrackerDB", defaults, true)
    
    -- Compatibilidad para archivos antiguos que buscan la global
    _G.AscensionQuestTrackerDB = self.db.profile 
end

function AQT:OnEnable()
    self:CreateUI()
    -- Registrar opciones DESPUÉS de crear la UI y cargar DB
    if self.SetupOptions then self:SetupOptions() end
    
    self:RegisterEvents()
    self:FullUpdate()
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------
function AQT:CreateUI()
    -- Main Container
    local Container = CreateFrame("Frame", "AscensionQuestTrackerFrame", UIParent)
    Container:SetClampedToScreen(true)
    Container:SetMovable(true)
    Container:RegisterForDrag("LeftButton")
    
    -- ScrollFrame
    local ScrollFrame = CreateFrame("ScrollFrame", nil, Container)
    ScrollFrame:SetPoint("TOPLEFT", 0, 0)
    ScrollFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    ScrollFrame:EnableMouseWheel(true)
    
    -- Content Frame (Donde se dibujan las lineas)
    local Content = CreateFrame("Frame", nil, ScrollFrame)
    Content:SetSize(260, 100)
    ScrollFrame:SetScrollChild(Content)
    
    -- Mouse Wheel
    ScrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local new = current - (delta * 30)
        if new < 0 then new = 0 end
        local max = self:GetVerticalScrollRange()
        if new > max then new = max end
        self:SetVerticalScroll(new)
    end)
    
    -- Drag Logic
    Container:SetScript("OnDragStart", function(self)
        if not AQT.db.profile.locked then self:StartMoving() end
    end)
    Container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, rel, x, y = self:GetPoint()
        AQT.db.profile.position = { point = point, relativePoint = rel, x = x, y = y }
    end)
    
    -- Guardamos las referencias en AQT para usarlas en los módulos
    self.Container = Container
    self.ScrollFrame = ScrollFrame
    self.Content = Content -- IMPORTANTE: Aquí es donde anclaremos las líneas
    
    self:UpdateLayout()
end

function AQT:UpdateLayout()
    local db = self.db.profile
    self.Container:SetScale(db.scale)
    self.Container:EnableMouse(not db.locked)
    
    if db.position then
        self.Container:ClearAllPoints()
        self.Container:SetPoint(db.position.point, UIParent, db.position.relativePoint, db.position.x, db.position.y)
    end
end

-- ASSETS
local ASSETS_FALLBACK = {
    font = "Fonts\\FRIZQT__.TTF", fontHeaderSize = 13, fontTextSize = 10,
    barTexture = "Interface\\Buttons\\WHITE8x8", barHeight = 4, padding = 10, spacing = 15,
    colors = { header = {r=1,g=0.9,b=0.5} }, animations = { fadeInDuration = 0.4, slideX = 20 }
}
ns.ASSETS = ns.Themes and ns.Themes.Default or ASSETS_FALLBACK

-- POOLS
AQT.lines = {}
AQT.bars = {}
AQT.itemButtons = {}

function AQT:GetLine(index)
    if not self.lines[index] then
        local f = CreateFrame("Button", nil, self.Content) -- Parent = self.Content
        f:SetSize(260, 16)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetAllPoints(f)
        f.text:SetJustifyH("RIGHT") 
        f.text:SetWordWrap(true)
        f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        self.lines[index] = f
    end
    local line = self.lines[index]
    line:EnableMouse(false)
    line:SetScript("OnClick", nil); line:SetScript("OnEnter", nil); line:SetScript("OnLeave", nil)
    line:SetAlpha(1)
    if line.icon then line.icon:Hide() end
    if line.indentLine then line.indentLine:Hide() end
    return line
end

function AQT:GetBar(index)
    if not self.bars[index] then
        local b = CreateFrame("StatusBar", nil, self.Content, "BackdropTemplate")
        b:SetStatusBarTexture(ns.ASSETS.barTexture)
        b:SetMinMaxValues(0, 1)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(ns.ASSETS.barTexture)
        bg:SetAllPoints(true)
        bg:SetVertexColor(0.1, 0.1, 0.1, 0.6)
        b.bg = bg
        self.bars[index] = b
    end
    if self.bars[index].bg then self.bars[index].bg:Show() end
    return self.bars[index]
end

-- Secure Item Button Pool
function AQT:GetItemButton(index)
    if not self.itemButtons[index] then
        local name = "AQTItemButton" .. index
        -- Create a SecureActionButton so it can trigger items/spells
        local b = CreateFrame("Button", name, self.Container, "SecureActionButtonTemplate")
        b:SetSize(22, 22)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
        
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        
        b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        
        -- Click handlers: Use AnyUp/AnyDown for better responsiveness
        b:RegisterForClicks("AnyUp", "AnyDown")
        
        -- Tooltip logic
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

function AQT.SafelySetText(fontString, text)
    if fontString then fontString:SetText(text or "") end
end

function AQT:FullUpdate()
    if not self.db then return end
    local db = self.db.profile
    local ASSETS = ns.ASSETS
    
    -- Sync Settings
    ASSETS.fontHeaderSize = db.fontHeaderSize
    ASSETS.fontTextSize = db.fontTextSize
    ASSETS.lineSpacing = db.lineSpacing
    ASSETS.spacing = db.sectionSpacing

    if not InCombatLockdown() then
        for _, itm in ipairs(self.itemButtons) do itm:Hide() end
    end
    
    local y, lIdx, bIdx = -ASSETS.padding, 1, 1
    
    -- Render Modules
    if self.RenderScenario then y, lIdx, bIdx = self:RenderScenario(y, lIdx, bIdx) end
    if self.RenderWidgets then y, lIdx, bIdx = self:RenderWidgets(y, lIdx, bIdx) end
    local itemIdx = 1
    if self.RenderQuests then y, lIdx, bIdx, itemIdx = self:RenderQuests(y, lIdx, bIdx, itemIdx) end
    if self.RenderAchievements then y, lIdx = self:RenderAchievements(y, lIdx) end
    
    -- Hide Unused
    for i = lIdx, #self.lines do if self.lines[i] then self.lines[i]:Hide() end end
    for i = bIdx, #self.bars do if self.bars[i] then self.bars[i]:Hide() end end
    
    -- Resize Logic
    local contentHeight = math.abs(y) + ASSETS.padding
    local maxWidth = db.width
    local maxHeight = db.maxHeight
    
    self.Content:SetSize(maxWidth, contentHeight)
    
    local finalHeight = math.min(contentHeight, maxHeight)
    if finalHeight < 50 then finalHeight = 50 end
    
    self.Container:SetSize(maxWidth, finalHeight)
    
    if self.ScrollFrame.UpdateScrollChildRect then self.ScrollFrame:UpdateScrollChildRect() end
end

function AQT:RegisterEvents()
    self:RegisterEvent("PLAYER_LOGIN", "FullUpdate")
    self:RegisterEvent("QUEST_LOG_UPDATE", "FullUpdate")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "FullUpdate")
    self:RegisterEvent("SUPER_TRACKING_CHANGED", "FullUpdate")
    self:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE", "FullUpdate")
    self:RegisterEvent("SCENARIO_UPDATE", "FullUpdate")
    self:RegisterEvent("ENCOUNTER_START", function() self.inBossCombat = true; self:FullUpdate() end)
    self:RegisterEvent("ENCOUNTER_END", function() self.inBossCombat = false; self:FullUpdate() end)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "FullUpdate")
    self:RegisterEvent("QUEST_TURNED_IN", "FullUpdate")
    self:RegisterEvent("QUEST_ACCEPTED", "FullUpdate")
    self:RegisterEvent("QUEST_REMOVED", "FullUpdate")
    self:RegisterEvent("UNIT_QUEST_LOG_CHANGED", "FullUpdate")
    self:RegisterEvent("UPDATE_UI_WIDGET", "FullUpdate")
end
