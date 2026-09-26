-- VendorAlert: ventana de notas y gastos, e icono del minimapa
local ADDON_NAME, ns = ...

local WIDTH, HEIGHT, MIN_HEIGHT = 380, 280, 30
local frame, notesPanel, statsPanel, editBox, minButton
local tabs, statCells = {}, {}
local L = ns.L
local localized = {} -- { objeto, clave } para volver a traducir al cambiar de idioma

-- Pone el texto traducido y lo recuerda para ApplyLanguage
local function SetL(obj, key)
    obj:SetText(L[key])
    table.insert(localized, { obj, key })
end

function ns.ApplyLanguage()
    for _, entry in ipairs(localized) do entry[1]:SetText(L[entry[2]]) end
end

-- Crea un frame probando plantillas por orden (algunas cambian entre versiones del juego)
local function CreateWithTemplate(kind, name, parent, ...)
    for i = 1, select("#", ...) do
        local ok, obj = pcall(CreateFrame, kind, name, parent, (select(i, ...)))
        if ok and obj then return obj end
    end
    return CreateFrame(kind, name, parent)
end

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.DB.window.pos = { point, relPoint, x, y }
end

----------------------------------------------------------------------
-- Estado: pestañas y minimizar
----------------------------------------------------------------------
local function SetTab(which)
    ns.DB.window.tab = which
    notesPanel:SetShown(which == "notes" and not ns.DB.window.minimized)
    statsPanel:SetShown(which == "stats" and not ns.DB.window.minimized)
    for key, tab in pairs(tabs) do
        if key == which then tab:LockHighlight() else tab:UnlockHighlight() end
    end
    if which == "stats" then ns.RefreshStats() end
end

local function SetMinimized(minimized)
    ns.DB.window.minimized = minimized
    frame:SetHeight(minimized and MIN_HEIGHT or HEIGHT)
    if frame.Inset then frame.Inset:SetShown(not minimized) end
    for _, tab in pairs(tabs) do tab:SetShown(not minimized) end
    minButton:SetText(minimized and "+" or "–")
    if minimized and editBox then editBox:ClearFocus() end
    SetTab(ns.DB.window.tab)
end

function ns.ToggleWindow(tab)
    if not frame then return end
    if tab and frame:IsShown() and ns.DB.window.tab ~= tab then
        SetTab(tab)
        if ns.DB.window.minimized then SetMinimized(false) end
        return
    end
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then
        if tab then SetTab(tab) end
        if ns.DB.window.minimized and tab then SetMinimized(false) end
    end
end

----------------------------------------------------------------------
-- Pestaña de notas
----------------------------------------------------------------------
local function BuildNotes()
    notesPanel = CreateFrame("Frame", nil, frame)
    notesPanel:SetPoint("TOPLEFT", 12, -60)
    notesPanel:SetPoint("BOTTOMRIGHT", -12, 10)

    local scroll = CreateWithTemplate("ScrollFrame", "VendorAlertNotesScroll", notesPanel,
        "UIPanelScrollFrameTemplate", "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -24, 0)

    editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(WIDTH - 60)
    editBox:SetHeight(HEIGHT - 80)
    editBox:SetMaxLetters(4000)
    editBox:SetText(ns.CharDB.notes or "")
    scroll:SetScrollChild(editBox)

    local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    placeholder:SetPoint("TOPLEFT", 2, -2)
    SetL(placeholder, "PLACEHOLDER")
    placeholder:SetShown(editBox:GetText() == "")

    editBox:SetScript("OnTextChanged", function(self, userInput)
        placeholder:SetShown(self:GetText() == "")
        if userInput then ns.CharDB.notes = self:GetText() end
    end)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Mantiene visible la línea donde escribes
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, h)
        local top, offset, height = -y, scroll:GetVerticalScroll(), scroll:GetHeight()
        if top < offset then
            scroll:SetVerticalScroll(top)
        elseif top + h > offset + height then
            scroll:SetVerticalScroll(top + h - height)
        end
    end)
    -- Clic en cualquier parte del área para empezar a escribir
    scroll:EnableMouse(true)
    scroll:SetScript("OnMouseDown", function() editBox:SetFocus() end)
end

----------------------------------------------------------------------
-- Pestaña de gastos
----------------------------------------------------------------------
local function BuildStats()
    statsPanel = CreateFrame("Frame", nil, frame)
    statsPanel:SetPoint("TOPLEFT", 16, -64)
    statsPanel:SetPoint("BOTTOMRIGHT", -16, 12)

    local cols = { { x = 0, w = 70 }, { x = 72, w = 90 }, { x = 164, w = 90 }, { x = 256, w = 90 } }
    local headers = { false, "COL_REPAIRS", "COL_SALES", "COL_BALANCE" }
    local rows = { { key = "week", label = "WEEK" }, { key = "month", label = "MONTH" }, { key = "total", label = "TOTAL" } }

    local function Cell(row, col, key, font)
        local fs = statsPanel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", cols[col].x, -row * 26)
        fs:SetWidth(cols[col].w)
        fs:SetJustifyH(col == 1 and "LEFT" or "RIGHT")
        if key then SetL(fs, key) end
        return fs
    end

    for c, h in ipairs(headers) do Cell(0, c, h or nil, "GameFontNormalSmall") end
    for r, row in ipairs(rows) do
        Cell(r, 1, row.label, "GameFontNormalSmall")
        statCells[row.key] = { repair = Cell(r, 2), sales = Cell(r, 3), net = Cell(r, 4) }
    end

    local info = statsPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", 0, -4 * 26 - 6)
    info:SetWidth(WIDTH - 40)
    info:SetJustifyH("LEFT")
    SetL(info, "STATS_INFO")

    local reset = CreateWithTemplate("Button", nil, statsPanel, "UIPanelButtonTemplate")
    reset:SetSize(90, 22)
    reset:SetPoint("BOTTOMRIGHT", 0, 0)
    SetL(reset, "RESET_BUTTON")
    reset:SetScript("OnClick", ns.ResetStats)
end

function ns.RefreshStats()
    if not statsPanel or not statsPanel:IsShown() then return end
    local st = ns.GetStats()
    for key, cells in pairs(statCells) do
        local v = st[key]
        local net = v.sales - v.repair
        cells.repair:SetText(ns.Money(v.repair))
        cells.sales:SetText(ns.Money(v.sales))
        cells.net:SetText((net < 0 and "|cffff6060-|r" or "") .. ns.Money(math.abs(net)))
    end
end

----------------------------------------------------------------------
-- Ventana principal
----------------------------------------------------------------------
local function BuildWindow()
    frame = CreateWithTemplate("Frame", "VendorAlertFrame", UIParent, "BasicFrameTemplateWithInset", "BackdropTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)

    if not frame.CloseButton then -- sin plantilla: fondo y botón de cierre propios
        if frame.SetBackdrop then
            frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
                insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            frame:SetBackdropColor(0, 0, 0, 0.9)
        end
        frame.CloseButton = CreateWithTemplate("Button", nil, frame, "UIPanelCloseButton")
        frame.CloseButton:SetPoint("TOPRIGHT", 0, 0)
    end

    local pos = ns.DB.window.pos
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("CENTER", 0, 80)
    end

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("VendorAlert")

    minButton = CreateWithTemplate("Button", nil, frame, "UIPanelButtonTemplate")
    minButton:SetSize(22, 18)
    minButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", -2, 0)
    minButton:SetScript("OnClick", function() SetMinimized(not ns.DB.window.minimized) end)

    local x = 12
    for _, t in ipairs({ { key = "notes", text = "TAB_NOTES" }, { key = "stats", text = "TAB_STATS" } }) do
        local tab = CreateWithTemplate("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(80, 22)
        tab:SetPoint("TOPLEFT", x, -30)
        SetL(tab, t.text)
        tab:SetScript("OnClick", function() SetTab(t.key) end)
        tabs[t.key] = tab
        x = x + 84
    end

    BuildNotes()
    BuildStats()

    frame:SetScript("OnShow", function() ns.DB.window.shown = true; ns.RefreshStats() end)
    frame:SetScript("OnHide", function() ns.DB.window.shown = false; editBox:ClearFocus() end)
    table.insert(UISpecialFrames, "VendorAlertFrame") -- Esc la cierra

    SetMinimized(ns.DB.window.minimized)
    frame:SetShown(ns.DB.window.shown)
end

----------------------------------------------------------------------
-- Icono del minimapa
----------------------------------------------------------------------
local mmButton

local function PlaceMinimapButton()
    local angle = math.rad(ns.DB.minimap.angle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function ns.UpdateMinimapButton()
    if mmButton then mmButton:SetShown(not ns.DB.minimap.hide) end
end

local function BuildMinimapButton()
    mmButton = CreateFrame("Button", "VendorAlertMinimapButton", Minimap)
    mmButton:SetSize(31, 31)
    mmButton:SetFrameStrata("MEDIUM")
    mmButton:SetFrameLevel(8)
    mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mmButton:RegisterForDrag("LeftButton")
    mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = mmButton:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = mmButton:CreateTexture(nil, "ARTWORK")
    icon:SetSize(17, 17)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:SetPoint("TOPLEFT", 7, -6)

    local border = mmButton:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    mmButton:SetScript("OnClick", function(_, button)
        ns.ToggleWindow(button == "RightButton" and "stats" or "notes")
    end)

    -- Arrastrar alrededor del minimapa
    mmButton:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local atan2 = math.atan2 or math.atan
            ns.DB.minimap.angle = math.deg(atan2(cy / scale - my, cx / scale - mx))
            PlaceMinimapButton()
        end)
    end)
    mmButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    mmButton:SetScript("OnEnter", function(self)
        local fill, used, total = ns.BagFill()
        local st = ns.GetStats()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("VendorAlert")
        GameTooltip:AddDoubleLine(L.TT_BAGS, string.format("%d/%d (%d%%)", used, total, ns.Pct(fill)), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.TT_DUR, ns.Pct(ns.LowestDurability()) .. "%", 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.TT_WEEK_REPAIRS, ns.Money(st.week.repair), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddDoubleLine(L.TT_WEEK_SALES, ns.Money(st.week.sales), 1, 1, 1, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TT_LEFT, 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L.TT_RIGHT, 0.6, 0.6, 0.6)
        GameTooltip:AddLine(L.TT_DRAG, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    PlaceMinimapButton()
    ns.UpdateMinimapButton()
end

table.insert(ns.onLoad, function()
    ns.CharDB.notes = ns.CharDB.notes or ""
    local w = ns.DB.window
    if w.shown == nil then w.shown = false end
    if w.minimized == nil then w.minimized = false end
    w.tab = w.tab or "notes"
    ns.DB.minimap.angle = ns.DB.minimap.angle or 200
    BuildWindow()
    BuildMinimapButton()
end)
