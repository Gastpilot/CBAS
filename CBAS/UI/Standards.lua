-- CBAS - Standards: Minimap-Knopf, Eintrag unter Optionen > AddOns, Addon-Fach-Tooltip
local ADDON, ns = ...
local STD = {}
ns.Standards = STD

local ICON = "Interface\\AddOns\\CBAS\\Media\\Unicorn"

local function Tooltip(owner, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_LEFT")
    GameTooltip:AddLine("|cff33ccffCraphunts Blacklisted Addon Suite|r " .. (ns.VERSION or ""))
    local newer = ns.Version and ns.Version.Latest()
    if newer then GameTooltip:AddLine("Neue Version " .. newer .. " verfügbar!", 0.25, 1, 0.25) end
    if ns.Layer and ns.Layer.cur and ns.Layer.Label then
        local ok, lbl = pcall(ns.Layer.Label, ns.Layer.cur)
        if ok and lbl then GameTooltip:AddLine("Layer: " .. lbl, 1, 1, 1) end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Linksklick", "Fenster öffnen/schließen", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Rechtsklick", "Optionen-Menü", 1, 0.82, 0, 1, 1, 1)
    GameTooltip:AddDoubleLine("Umschalt+Klick", "Flipper", 1, 0.82, 0, 1, 1, 1)
    if owner == STD.button then GameTooltip:AddDoubleLine("Ziehen", "Knopf verschieben", 1, 0.82, 0, 1, 1, 1) end
    GameTooltip:Show()
end

local function Toggle(key, default)
    local st = ns.db.settings
    local cur = st[key]
    if cur == nil then cur = default end
    st[key] = not cur
    if key == "flagEN" and ns.ChatFlags and ns.ChatFlags.ClearCache then ns.ChatFlags.ClearCache() end
    if ns.ChatFlags and ns.ChatFlags.UpdateSettings then pcall(ns.ChatFlags.UpdateSettings) end
end

local function IsOn(key, default)
    local v = ns.db.settings[key]
    if v == nil then return default end
    return v and true or false
end

-- Rechtsklick-Menue (Blizzard MenuUtil, ab 11.0)
function STD.ShowMenu(owner)
    local S = ns.Suite
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        if S then S:Toggle("settings") end
        return
    end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle("CBAS " .. (ns.VERSION or ""))
        root:CreateButton("Lage", function() S:Toggle("home") end)
        root:CreateButton("GScout", function() S:Toggle("gscout") end)
        root:CreateButton("Geierwacht", function() S:Toggle("geier") end)
        root:CreateButton("Can I have it", function() S:Toggle("cihi") end)
        root:CreateButton("Flipper", function() S:Toggle("flipper") end)
        root:CreateDivider()
        root:CreateTitle("Optionen")
        root:CreateCheckbox("Länderflaggen im Chat", function() return IsOn("chatFlags", true) end,
            function() Toggle("chatFlags", true) end)
        root:CreateCheckbox("Englisch mit EN kennzeichnen", function() return IsOn("flagEN", true) end,
            function() Toggle("flagEN", true) end)
        root:CreateCheckbox("Infos in der Gruppensuche", function() return IsOn("lfgInfo", true) end,
            function() Toggle("lfgInfo", true) end)
        root:CreateCheckbox("Warn-Symbole in der Gruppensuche", function() return IsOn("lfgBadges", true) end,
            function() Toggle("lfgBadges", true); if ns.LFGInfo then pcall(ns.LFGInfo.RefreshRows) end end)
        root:CreateCheckbox("Layerwechsel im Chat melden", function() return IsOn("layerChat", false) end,
            function() Toggle("layerChat", false) end)
        local cihi = ns.db.settings.cihi
        if cihi then
            root:CreateCheckbox("Can-I-have-it-Popup", function() return cihi.popup ~= false end,
                function() cihi.popup = (cihi.popup == false) end)
        end
        root:CreateDivider()
        root:CreateButton("Alle Einstellungen", function() S:Toggle("settings") end)
        local newer = ns.Version and ns.Version.Latest()
        if newer then
            root:CreateButton("|cff40ff40Update " .. newer .. " - Link anzeigen|r", function() S:Toggle("settings") end)
        end
        root:CreateButton("Minimap-Knopf ausblenden", function()
            STD.SetMinimap(false)
            ns.Print("Minimap-Knopf ausgeblendet. Zurück mit /crap minimap.")
        end)
    end)
end

local function OnClick(button, owner)
    local S = ns.Suite
    if not S then return end
    if IsShiftKeyDown() then S:Toggle("flipper")
    elseif button == "RightButton" then
        if owner then STD.ShowMenu(owner) else S:Toggle("settings") end
    else S:Toggle() end
end

---------------------------------------------------------------------------
-- Minimap-Knopf (wie LibDBIcon, ohne Bibliothek)
---------------------------------------------------------------------------
local function Cfg() return ns.db.settings end

local function UpdatePosition(b)
    local angle = math.rad(Cfg().minimapAngle or 215)
    local x, y = math.cos(angle), math.sin(angle)
    local r = (Minimap:GetWidth() / 2) + 5
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", x * r, y * r)
end

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    return math.atan(y, x)
end

function STD.CreateMinimapButton()
    if STD.button or not Minimap then return end
    local b = CreateFrame("Button", "CBASMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    -- Einhorn: goldenes Einhorn auf dunkelblauer Scheibe (Farbe wie Polestar), ohne klassischen Rand
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetTexture(ICON)
    icon:SetPoint("CENTER")
    b.icon = icon
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetSize(26, 26)
    hl:SetTexture(ICON)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.35)
    hl:SetPoint("CENTER")
    b:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", 1, -1) end)
    b:SetScript("OnMouseUp", function() icon:SetPoint("CENTER") end)
    -- gruener Punkt bei neuer Version
    local dot = b:CreateTexture(nil, "OVERLAY", nil, 7)
    dot:SetSize(7, 7)
    dot:SetColorTexture(0.2, 1, 0.2, 1)
    dot:SetPoint("TOPRIGHT", -3, -3)
    dot:Hide()
    b.dot = dot
    b:SetScript("OnClick", function(self, button) OnClick(button, self) end)
    b:SetScript("OnEnter", function(self) Tooltip(self, "ANCHOR_LEFT") end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            Cfg().minimapAngle = math.deg(Atan2(py - my, px - mx)) % 360
            UpdatePosition(self)
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    STD.button = b
    UpdatePosition(b)
    STD.UpdateMinimap()
end

function STD.UpdateMinimap()
    local b = STD.button
    if not b then return end
    b:SetShown(not Cfg().minimapHide)
    b.dot:SetShown(ns.Version and ns.Version.Latest() and true or false)
end

function STD.SetMinimap(show)
    Cfg().minimapHide = not show
    STD.UpdateMinimap()
end

---------------------------------------------------------------------------
-- Optionen > AddOns > CBAS
---------------------------------------------------------------------------
function STD.CreateOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "CBAS"
    local t = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("|cff33ccffCraphunts Blacklisted Addon Suite|r")
    local v = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    v:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    v:SetText("Version " .. (ns.VERSION or "?") .. " · /crap · GScout, Geierwacht, Can I have it, Flipper")
    local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", v, "BOTTOMLEFT", 0, -14)
    d:SetWidth(560)
    d:SetJustifyH("LEFT")
    d:SetText("Alle Einstellungen findest du im CBAS-Fenster links unten unter „Einstellungen“.")
    local function Btn(text, y, fn)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(200, 24)
        b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, y)
        b:SetText(text)
        b:SetScript("OnClick", function()
            if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then HideUIPanel(SettingsPanel) end
            fn()
        end)
        return b
    end
    Btn("CBAS öffnen", -16, function() ns.Suite:Toggle() end)
    Btn("Einstellungen", -46, function() ns.Suite:Toggle("settings") end)
    local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", d, "BOTTOMLEFT", -4, -82)
    local cbt = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    cbt:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cbt:SetText("Minimap-Knopf anzeigen")
    cb:SetScript("OnClick", function(c) STD.SetMinimap(c:GetChecked()) end)
    cb:SetScript("OnShow", function(c) c:SetChecked(not Cfg().minimapHide) end)
    local link = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    link:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -122)
    link:SetText("Download/Updates: " .. (ns.Version and ns.Version.URL or ""))
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, "CBAS")
        if ok and cat then pcall(Settings.RegisterAddOnCategory, cat); STD.category = cat end
    elseif InterfaceOptions_AddCategory then
        pcall(InterfaceOptions_AddCategory, panel)
    end
    STD.panel = panel
end

---------------------------------------------------------------------------
-- Addon-Fach (Minimap-Menue von Blizzard)
---------------------------------------------------------------------------
function CBAS_OnCompartmentEnter(_, button) Tooltip(button or UIParent, "ANCHOR_LEFT") end
function CBAS_OnCompartmentLeave() GameTooltip:Hide() end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    pcall(STD.CreateMinimapButton)
    pcall(STD.CreateOptionsPanel)
    -- gruener Punkt nach Versions-Meldungen nachziehen
    C_Timer.After(25, function() pcall(STD.UpdateMinimap) end)
end)
