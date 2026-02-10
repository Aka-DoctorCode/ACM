-- --------------------------------------------------------------------------------
-- -- CONFIGURATION MODULE
-- --------------------------------------------------------------------------------
-- local addonName, addonTable = ...

-- -- 1. Default Settings
-- local defaults = {
--     position = { point = "RIGHT", relativePoint = "RIGHT", x = -50, y = 0 },
--     scale = 1.0,
--     hideOnBoss = true,
--     autoSuperTrack = false,
--     locked = false,
--     maxHeight = 600,
--     width = 260,
--     fontHeaderSize = 13,
--     fontTextSize = 10,
--     lineSpacing = 6,
--     sectionSpacing = 15
-- }

-- -- 2. Database Handling (SavedVariables)
-- function addonTable.LoadDatabase()
--     -- Create DB if it doesn't exist
--     if not AscensionQuestTrackerDB then
--         AscensionQuestTrackerDB = {}
--     end
    
--     -- Populate missing defaults
--     for key, value in pairs(defaults) do
--         if AscensionQuestTrackerDB[key] == nil then
--             AscensionQuestTrackerDB[key] = value
--         end
--     end
    
--     -- Deep copy for position if missing
--     if not AscensionQuestTrackerDB.position then
--         AscensionQuestTrackerDB.position = defaults.position
--     end
-- end

-- -- 3. Create Options Panel
-- local function CreateOptionsPanel()
--     local panel = CreateFrame("Frame", "AscensionQT_OptionsPanel", UIParent)
--     panel.name = "Ascension Quest Tracker"
    
--     -- Title
--     local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
--     title:SetPoint("TOPLEFT", 16, -16)
--     title:SetText("Ascension Quest Tracker Settings")
    
--     -- CHECKBOX: Hide on Boss
--     local cbHide = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
--     cbHide:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
--     cbHide.Text:SetText("Hide Quests during Boss Encounters")
--     cbHide:SetChecked(AscensionQuestTrackerDB.hideOnBoss)
--     cbHide:SetScript("OnClick", function(self)
--         AscensionQuestTrackerDB.hideOnBoss = self:GetChecked()
--         -- Trigger update in main addon
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
--             AscensionQuestTrackerFrame:FullUpdate()
--         end
--     end)
    
--     -- CHECKBOX: Lock Tracker
--     local cbLock = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
--     cbLock:SetPoint("TOPLEFT", cbHide, "BOTTOMLEFT", 0, -10)
--     cbLock.Text:SetText("Lock Position")
--     cbLock:SetChecked(AscensionQuestTrackerDB.locked)
--     cbLock:SetScript("OnClick", function(self)
--         AscensionQuestTrackerDB.locked = self:GetChecked()
--         if AscensionQuestTrackerFrame then
--             AscensionQuestTrackerFrame:EnableMouse(not AscensionQuestTrackerDB.locked)
--         end
--     end)

--     -- CHECKBOX: Auto Super Track
--     local cbAutoTrack = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
--     cbAutoTrack:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -10)
--     cbAutoTrack.Text:SetText("Auto-Select Closest Quest (If none tracked)")
--     cbAutoTrack:SetChecked(AscensionQuestTrackerDB.autoSuperTrack)
--     cbAutoTrack:SetScript("OnClick", function(self)
--         AscensionQuestTrackerDB.autoSuperTrack = self:GetChecked()
--     end)

--     -- SLIDER: Scale
--     local sliderHeight = CreateFrame("Slider", "AscensionQT_HeightSlider", panel, "OptionsSliderTemplate")
--     sliderHeight:SetPoint("TOPLEFT", sliderScale, "BOTTOMLEFT", 0, -30)
--     sliderHeight:SetMinMaxValues(200, 1500)
--     sliderHeight:SetValue(AscensionQuestTrackerDB.maxHeight or 600)
--     sliderHeight:SetValueStep(10)
--     sliderHeight:SetObeyStepOnDrag(true)

--     _G[sliderHeight:GetName() .. "Low"]:SetText("200")
--     _G[sliderHeight:GetName() .. "High"]:SetText("1500")
--     _G[sliderHeight:GetName() .. "Text"]:SetText("Max Height: " .. (AscensionQuestTrackerDB.maxHeight or 600))

--     sliderHeight:SetScript("OnValueChanged", function(self, value)
--         local val = math.floor(value)
--         AscensionQuestTrackerDB.maxHeight = val
--         _G[self:GetName() .. "Text"]:SetText("Max Height: " .. val)
        
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then
--             AscensionQuestTrackerFrame:FullUpdate()
--         end
--     end)

--     -- 1. SLIDER: Frame Width
--     local sliderWidth = CreateFrame("Slider", "AscensionQT_WidthSlider", panel, "OptionsSliderTemplate")
--     sliderWidth:SetPoint("TOPLEFT", sliderHeight, "BOTTOMLEFT", 0, -30)
--     sliderWidth:SetMinMaxValues(200, 600)
--     sliderWidth:SetValue(AscensionQuestTrackerDB.width or 260)
--     sliderWidth:SetValueStep(10)
--     sliderWidth:SetObeyStepOnDrag(true)
--     _G[sliderWidth:GetName() .. "Low"]:SetText("200")
--     _G[sliderWidth:GetName() .. "High"]:SetText("600")
--     _G[sliderWidth:GetName() .. "Text"]:SetText("Tracker Width: " .. (AscensionQuestTrackerDB.width or 260))
--     sliderWidth:SetScript("OnValueChanged", function(self, value)
--         local val = math.floor(value)
--         AscensionQuestTrackerDB.width = val
--         _G[self:GetName() .. "Text"]:SetText("Tracker Width: " .. val)
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then AscensionQuestTrackerFrame:FullUpdate() end
--     end)

--     -- 2. SLIDER: Header Font Size
--     local sliderHFont = CreateFrame("Slider", "AscensionQT_HFontSlider", panel, "OptionsSliderTemplate")
--     sliderHFont:SetPoint("TOPLEFT", sliderWidth, "BOTTOMLEFT", 0, -30)
--     sliderHFont:SetMinMaxValues(10, 30)
--     sliderHFont:SetValue(AscensionQuestTrackerDB.fontHeaderSize or 13)
--     sliderHFont:SetValueStep(1)
--     sliderHFont:SetObeyStepOnDrag(true)
--     _G[sliderHFont:GetName() .. "Low"]:SetText("10")
--     _G[sliderHFont:GetName() .. "High"]:SetText("30")
--     _G[sliderHFont:GetName() .. "Text"]:SetText("Header Font Size: " .. (AscensionQuestTrackerDB.fontHeaderSize or 13))
--     sliderHFont:SetScript("OnValueChanged", function(self, value)
--         local val = math.floor(value)
--         AscensionQuestTrackerDB.fontHeaderSize = val
--         _G[self:GetName() .. "Text"]:SetText("Header Font Size: " .. val)
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then AscensionQuestTrackerFrame:FullUpdate() end
--     end)

--     -- 3. SLIDER: Text Font Size
--     local sliderTFont = CreateFrame("Slider", "AscensionQT_TFontSlider", panel, "OptionsSliderTemplate")
--     sliderTFont:SetPoint("LEFT", sliderHFont, "RIGHT", 40, 0) -- Side by side
--     sliderTFont:SetMinMaxValues(8, 24)
--     sliderTFont:SetValue(AscensionQuestTrackerDB.fontTextSize or 10)
--     sliderTFont:SetValueStep(1)
--     sliderTFont:SetObeyStepOnDrag(true)
--     _G[sliderTFont:GetName() .. "Low"]:SetText("8")
--     _G[sliderTFont:GetName() .. "High"]:SetText("24")
--     _G[sliderTFont:GetName() .. "Text"]:SetText("Text Font Size: " .. (AscensionQuestTrackerDB.fontTextSize or 10))
--     sliderTFont:SetScript("OnValueChanged", function(self, value)
--         local val = math.floor(value)
--         AscensionQuestTrackerDB.fontTextSize = val
--         _G[self:GetName() .. "Text"]:SetText("Text Font Size: " .. val)
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then AscensionQuestTrackerFrame:FullUpdate() end
--     end)

--     -- 4. SLIDER: Line Spacing (Padding)
--     local sliderLineSp = CreateFrame("Slider", "AscensionQT_LineSpSlider", panel, "OptionsSliderTemplate")
--     sliderLineSp:SetPoint("TOPLEFT", sliderHFont, "BOTTOMLEFT", 0, -30)
--     sliderLineSp:SetMinMaxValues(0, 20)
--     sliderLineSp:SetValue(AscensionQuestTrackerDB.lineSpacing or 6)
--     sliderLineSp:SetValueStep(1)
--     sliderLineSp:SetObeyStepOnDrag(true)
--     _G[sliderLineSp:GetName() .. "Low"]:SetText("0")
--     _G[sliderLineSp:GetName() .. "High"]:SetText("20")
--     _G[sliderLineSp:GetName() .. "Text"]:SetText("Line Spacing: " .. (AscensionQuestTrackerDB.lineSpacing or 6))
--     sliderLineSp:SetScript("OnValueChanged", function(self, value)
--         local val = math.floor(value)
--         AscensionQuestTrackerDB.lineSpacing = val
--         _G[self:GetName() .. "Text"]:SetText("Line Spacing: " .. val)
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then AscensionQuestTrackerFrame:FullUpdate() end
--     end)

--     -- 5. SLIDER: Section Spacing
--     local sliderSecSp = CreateFrame("Slider", "AscensionQT_SecSpSlider", panel, "OptionsSliderTemplate")
--     sliderSecSp:SetPoint("LEFT", sliderLineSp, "RIGHT", 40, 0) -- Side by side
--     sliderSecSp:SetMinMaxValues(0, 50)
--     sliderSecSp:SetValue(AscensionQuestTrackerDB.sectionSpacing or 15)
--     sliderSecSp:SetValueStep(1)
--     sliderSecSp:SetObeyStepOnDrag(true)
--     _G[sliderSecSp:GetName() .. "Low"]:SetText("0")
--     _G[sliderSecSp:GetName() .. "High"]:SetText("50")
--     _G[sliderSecSp:GetName() .. "Text"]:SetText("Section Spacing: " .. (AscensionQuestTrackerDB.sectionSpacing or 15))
--     sliderSecSp:SetScript("OnValueChanged", function(self, value)
--         local val = math.floor(value)
--         AscensionQuestTrackerDB.sectionSpacing = val
--         _G[self:GetName() .. "Text"]:SetText("Section Spacing: " .. val)
--         if AscensionQuestTrackerFrame and AscensionQuestTrackerFrame.FullUpdate then AscensionQuestTrackerFrame:FullUpdate() end
--     end)

--     -- DESCRIPTION / HELP
--     local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
--     desc:SetPoint("TOPLEFT", sliderScale, "BOTTOMLEFT", 0, -20)
--     desc:SetText("Note: To move the tracker, ensure 'Lock Position' is unchecked.\nDrag the tracker with Left Click.")
    
--     -- Register to WoW Settings (Modern API support)
--     if Settings and Settings.RegisterCanvasLayoutCategory then
--         local category, layout = Settings.RegisterCanvasLayoutCategory(panel, "Ascension Quest Tracker")
--         Settings.RegisterAddOnCategory(category)
--     else
--         -- Fallback for older API versions
--         InterfaceOptions_AddCategory(panel)
--     end
-- end

-- -- Initialize Config on Login
-- local configLoader = CreateFrame("Frame")
-- configLoader:RegisterEvent("PLAYER_LOGIN")
-- configLoader:SetScript("OnEvent", function()
--     addonTable.LoadDatabase()
--     CreateOptionsPanel()
-- end)

local addonName, ns = ...
local AQT = LibStub("AceAddon-3.0"):GetAddon("AscensionQuestTracker")

-- Options Table Definition
function AQT:GetOptions()
    local options = {
        name = "Ascension Quest Tracker",
        handler = AQT,
        type = "group",
        args = {
            general = {
                type = "group",
                name = "General Settings",
                order = 1,
                inline = true,
                args = {
                    hideOnBoss = {
                        type = "toggle",
                        name = "Hide on Boss",
                        desc = "Automatically hide the tracker during boss encounters.",
                        order = 1,
                        get = function(info) return self.db.profile.hideOnBoss end,
                        set = function(info, val) 
                            self.db.profile.hideOnBoss = val
                            self:FullUpdate()
                        end,
                    },
                    locked = {
                        type = "toggle",
                        name = "Lock Position",
                        desc = "Lock the tracker frame to prevent accidental movement.",
                        order = 2,
                        get = function(info) return self.db.profile.locked end,
                        set = function(info, val) 
                            self.db.profile.locked = val
                            if AscensionQuestTrackerFrame then
                                AscensionQuestTrackerFrame:EnableMouse(not val)
                            end
                        end,
                    },
                    autoSuperTrack = {
                        type = "toggle",
                        name = "Auto Super Track",
                        desc = "Automatically track the closest quest if nothing is manually tracked.",
                        order = 3,
                        get = function(info) return self.db.profile.autoSuperTrack end,
                        set = function(info, val) self.db.profile.autoSuperTrack = val end,
                    },
                },
            },
            appearance = {
                type = "group",
                name = "Appearance & Sizing",
                order = 2,
                inline = true,
                args = {
                    scale = {
                        type = "range",
                        name = "Scale",
                        desc = "Adjust the global scale of the tracker.",
                        min = 0.5, max = 2.0, step = 0.1,
                        order = 1,
                        get = function(info) return self.db.profile.scale end,
                        set = function(info, val) 
                            self.db.profile.scale = val 
                            self:UpdateLayout() -- Call update on core
                        end,
                    },
                    maxHeight = {
                        type = "range",
                        name = "Max Height",
                        desc = "Maximum height before scrolling becomes active.",
                        min = 200, max = 1500, step = 10,
                        order = 2,
                        get = function(info) return self.db.profile.maxHeight end,
                        set = function(info, val) 
                            self.db.profile.maxHeight = val
                            self:FullUpdate()
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        desc = "Width of the tracker frame.",
                        min = 200, max = 600, step = 10,
                        order = 3,
                        get = function(info) return self.db.profile.width end,
                        set = function(info, val) 
                            self.db.profile.width = val
                            self:FullUpdate()
                        end,
                    },
                },
            },
            typography = {
                type = "group",
                name = "Typography & Spacing",
                order = 3,
                inline = true,
                args = {
                    fontHeaderSize = {
                        type = "range",
                        name = "Header Font Size",
                        min = 10, max = 30, step = 1,
                        order = 1,
                        get = function(info) return self.db.profile.fontHeaderSize end,
                        set = function(info, val) 
                            self.db.profile.fontHeaderSize = val
                            self:FullUpdate()
                        end,
                    },
                    fontTextSize = {
                        type = "range",
                        name = "Text Font Size",
                        min = 8, max = 24, step = 1,
                        order = 2,
                        get = function(info) return self.db.profile.fontTextSize end,
                        set = function(info, val) 
                            self.db.profile.fontTextSize = val
                            self:FullUpdate()
                        end,
                    },
                    lineSpacing = {
                        type = "range",
                        name = "Line Spacing",
                        min = 0, max = 20, step = 1,
                        order = 3,
                        get = function(info) return self.db.profile.lineSpacing end,
                        set = function(info, val) 
                            self.db.profile.lineSpacing = val
                            self:FullUpdate()
                        end,
                    },
                    sectionSpacing = {
                        type = "range",
                        name = "Section Spacing",
                        min = 0, max = 50, step = 1,
                        order = 4,
                        get = function(info) return self.db.profile.sectionSpacing end,
                        set = function(info, val) 
                            self.db.profile.sectionSpacing = val
                            self:FullUpdate()
                        end,
                    },
                },
            },
        },
    }
    return options
end

function AQT:SetupOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("AscensionQuestTracker", self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AscensionQuestTracker", "Ascension Quest Tracker")
    
    -- Chat Command
    self:RegisterChatCommand("aqt", function() 
        Settings.OpenToCategory("Ascension Quest Tracker") -- Modern WoW API
    end)
end