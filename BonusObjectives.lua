local addonName, ns = ...
local AQT = ns.AQT
local ASSETS = ns.ASSETS

-- Renders the progress bar for Bonus Objectives and World Quests
function AQT:RenderBonusObjectiveBar(qID, lineIdx, barIdx, width, yOffset)
    local isComplete = C_QuestLog.IsComplete(qID)
    
    if not isComplete and C_TaskQuest and C_TaskQuest.GetQuestProgressBarInfo then
        local progress = C_TaskQuest.GetQuestProgressBarInfo(qID)
        if progress then
            local pLine = self:GetLine(lineIdx)
            pLine:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, yOffset)
            pLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
            
            -- [FIX] Protección contra color nulo
            -- Si ASSETS.colors.wq no existe, usamos un Azul por defecto
            local color = {r=0.2, g=0.6, b=1, a=1}
            if ASSETS.colors and ASSETS.colors.wq then
                color = ASSETS.colors.wq
            end
            
            self.SafelySetText(pLine.text, string.format("Progress: %d%%", progress))
            pLine:Show()
            yOffset = yOffset - 12
            lineIdx = lineIdx + 1

            local bar = self:GetBar(barIdx)
            bar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -ASSETS.padding, yOffset)
            bar:SetSize(width - 20, ASSETS.barHeight)
            
            -- Asegurar textura (importante para visibilidad)
            bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            
            bar:SetValue(progress / 100)
            bar:SetStatusBarColor(color.r, color.g, color.b)
            bar:Show()
            yOffset = yOffset - 8
            barIdx = barIdx + 1
            
            return yOffset, lineIdx, barIdx, true -- Returns true to indicate a bar was rendered
        end
    end
    
    return yOffset, lineIdx, barIdx, false
end
