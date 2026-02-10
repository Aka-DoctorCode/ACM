local addonName, ns = ...
local AQT = ns.AQT
local ASSETS = ns.ASSETS

-- Helper seguro para colores
local function GetColor(group, fallback)
    if ASSETS.colors and ASSETS.colors[group] then
        return ASSETS.colors[group]
    end
    return fallback or {r=0, g=0.7, b=1, a=1} -- Azul por defecto
end

function AQT:RenderScenario(startY, lineIdx, barIdx)
    local yOffset = startY
    
    -- 1. Verificación básica
    if not C_Scenario or not C_Scenario.IsInScenario() then 
        return yOffset, lineIdx, barIdx 
    end

    ----------------------------------------------------------------------------
    -- A. TEMPORIZADOR (MÍTICAS+)
    ----------------------------------------------------------------------------
    local timerID = C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID and C_ChallengeMode.GetActiveChallengeMapID()
    if timerID then
        local level, activeAffixIDs = (C_ChallengeMode.GetActiveKeystoneInfo and C_ChallengeMode.GetActiveKeystoneInfo())
        local _, _, timeLimit = (C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(timerID))
        local _, elapsedTime = GetWorldElapsedTime(1)
        local timeRem = (timeLimit or 0) - (elapsedTime or 0)

        -- Header
        local header = self:GetLine(lineIdx)
        header.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize + 2, "OUTLINE")
        header:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
        
        local hBg = GetColor("headerBg", {r=0, g=0, b=0, a=0.5})
        -- header:SetBackdropColor(hBg.r, hBg.g, hBg.b, hBg.a) -- Backdrop removed in Core.lua
        header:SetSize(260, 24)
        
        self.SafelySetText(header.text, string.format("  +%d Keystone  ", level or 0))
        header:Show()
        yOffset = yOffset - 26
        lineIdx = lineIdx + 1

        -- Afijos
        if activeAffixIDs then
            local affixString = ""
            for _, affixID in ipairs(activeAffixIDs) do
                local affixName = C_ChallengeMode.GetAffixInfo(affixID)
                if affixName then
                    if affixString == "" then affixString = affixName else affixString = affixString .. ", " .. affixName end
                end
            end
            if affixString ~= "" then
                local affixLine = self:GetLine(lineIdx)
                affixLine.text:SetFont(ASSETS.font, 10, "OUTLINE")
                affixLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                self.SafelySetText(affixLine.text, affixString)
                affixLine:Show()
                yOffset = yOffset - 14
                lineIdx = lineIdx + 1
            end
        end

        -- Timer Texto
        local timerLine = self:GetLine(lineIdx)
        timerLine.text:SetFont(ASSETS.font, 18, "OUTLINE")
        timerLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
        self.SafelySetText(timerLine.text, self.FormatTime(timeRem))
        timerLine:Show()
        yOffset = yOffset - 22
        lineIdx = lineIdx + 1

        -- Timer Barra
        local timeBar = self:GetBar(barIdx)
        timeBar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
        timeBar:SetStatusBarTexture(ASSETS.barTexture or "Interface\\Buttons\\WHITE8x8") -- Asegurar Textura
        local width = (self.db and self.db.profile and self.db.profile.width) or 260
        timeBar:SetSize(width - 20, 6)
        timeBar:SetMinMaxValues(0, timeLimit or 1)
        timeBar:SetValue(timeLimit - timeRem)
        
        if timeRem < 60 then
            timeBar:SetStatusBarColor(1, 0, 0)
        else
            timeBar:SetStatusBarColor(0, 1, 0)
        end
        timeBar:Show()
        yOffset = yOffset - 12
        barIdx = barIdx + 1
    end
    
    ----------------------------------------------------------------------------
    -- B. OBJETIVOS DEL ESCENARIO
    ----------------------------------------------------------------------------
    local stageName, stageDesc, stepCriteriaCount = C_Scenario.GetStepInfo()
    
    -- Fallbacks de Nombre
    if not stageName then stageName = C_Scenario.GetInfo() end
    if not stageName then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then stageName = C_Map.GetMapInfo(mapID) and C_Map.GetMapInfo(mapID).name end
    end
    stageName = stageName or "Scenario"

    -- Conteo de Objetivos
    local numCriteria = stepCriteriaCount or 0
    if numCriteria == 0 and C_Scenario.GetNumCriteria then
         numCriteria = C_Scenario.GetNumCriteria() or 0
    end

    -- 1. Título
    local stageLine = self:GetLine(lineIdx)
    stageLine.text:SetFont(ASSETS.font, ASSETS.fontHeaderSize, "OUTLINE")
    stageLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
    local cHead = GetColor("header", {r=1, g=0.8, b=0})
    stageLine.text:SetTextColor(cHead.r, cHead.g, cHead.b)
    self.SafelySetText(stageLine.text, stageName)
    stageLine:Show()
    yOffset = yOffset - 16
    lineIdx = lineIdx + 1

    -- 2. Descripción
    if stageDesc and stageDesc ~= "" then
        local descLine = self:GetLine(lineIdx)
        descLine.text:SetFont(ASSETS.font, ASSETS.fontTextSize - 1)
        descLine:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
        descLine.text:SetTextColor(0.8, 0.8, 0.8)
        self.SafelySetText(descLine.text, stageDesc)
        descLine:Show()
        yOffset = yOffset - 14
        lineIdx = lineIdx + 1
    end

    -- 3. Bucle de Objetivos
    if C_Scenario.GetStepCriteriaInfo then
        for i = 1, numCriteria do
            local name, _, completed, quantity, totalQuantity, _, _, _, _, _, _, _, isWeighted = C_Scenario.GetStepCriteriaInfo(i)
            
            -- Sanitizar valores (Evitar errores de nil)
            quantity = quantity or 0
            
            if name and not completed then
                
                -- Lógica para forzar barra en objetivos de porcentaje
                if isWeighted and (not totalQuantity or totalQuantity == 0) then
                    totalQuantity = 100
                end

                -- A. Texto
                local line = self:GetLine(lineIdx)
                line.text:SetFont(ASSETS.font, ASSETS.fontTextSize, "OUTLINE")
                line:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                line.text:SetTextColor(1, 1, 1)

                local text = name
                if isWeighted then 
                    text = string.format("%s: %d%%", name, quantity)
                elseif totalQuantity and totalQuantity > 0 then
                    text = string.format("%s: %d/%d", name, quantity, totalQuantity)
                end
                
                self.SafelySetText(line.text, " - " .. text)
                line:Show()
                yOffset = yOffset - 12
                lineIdx = lineIdx + 1

                -- B. Barra de Progreso
                if totalQuantity and totalQuantity > 0 then
                    local bar = self:GetBar(barIdx)
                    local width = (self.db and self.db.profile and self.db.profile.width) or 260
                    
                    bar:SetPoint("TOPRIGHT", self.Content, "TOPRIGHT", -ASSETS.padding, yOffset)
                    bar:SetSize(width - 30, 8)
                    bar:SetStatusBarTexture(ASSETS.barTexture or "Interface\\Buttons\\WHITE8x8")
                    bar:SetMinMaxValues(0, totalQuantity)
                    bar:SetValue(quantity)
                    
                    -- Color Azul
                    local cBar = GetColor("scenarioBar", {r=0, g=0.7, b=1})
                    bar:SetStatusBarColor(cBar.r, cBar.g, cBar.b)
                    
                    bar:Show()
                    
                    yOffset = yOffset - 10
                    barIdx = barIdx + 1
                end
            end
        end
    end
    
    return yOffset - ASSETS.spacing, lineIdx, barIdx
end
