-- CBAS (Craphunts Blacklisted Addon Suite) - Suite-Fenster mit Reitern
-- Jedes Modul meldet sich mit ns.Suite:RegisterModule({ id, name, create, onShow }) an
-- und bekommt einen eigenen Reiter samt Inhaltsbereich.
local ADDON, ns = ...

local Suite = { modules = {}, panels = {}, tabs = {} }
ns.Suite = Suite

local WIDTH, HEIGHT = 860, 545   -- Inhaltsbereich je Modul
local TAB_H = 28                 -- Hoehe der Reiterleiste

-- Ziehen an einer beliebigen Flaeche bewegt das ganze Suite-Fenster
function Suite:MakeDraggable(region)
    region:EnableMouse(true)
    region:RegisterForDrag("LeftButton")
    region:SetScript("OnDragStart", function()
        if Suite.frame then Suite.frame:StartMoving() end
    end)
    region:SetScript("OnDragStop", function()
        if not Suite.frame then return end
        Suite.frame:StopMovingOrSizing()
        Suite:SavePosition()
    end)
end

function Suite:SavePosition()
    if not ns.db or not self.frame then return end
    local point, _, relPoint, x, y = self.frame:GetPoint(1)
    if point then ns.db.settings.framePos = { point, relPoint, x, y } end
end

function Suite:RestorePosition()
    local f = self.frame
    if not f then return end
    f:ClearAllPoints()
    local p = ns.db and ns.db.settings.framePos
    if p and p[1] then
        f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        f:SetPoint("CENTER")
    end
end

function Suite:ResetPosition()
    if ns.db then
        ns.db.settings.framePos = nil
        ns.db.settings.frameScale = nil
    end
    if self.frame then self.frame:SetScale(1) end
    self:RestorePosition()
    ns.Print("Fensterposition und -größe zurückgesetzt.")
end

---------------------------------------------------------------------------
-- Fenstergroesse: das ganze Fenster wird skaliert (Schrift, Listen, Knoepfe wachsen mit)
---------------------------------------------------------------------------
local MIN_SCALE, MAX_SCALE = 0.6, 2.0

-- Neue Groesse setzen, linke obere Ecke bleibt dabei stehen
function Suite:SetFrameScale(scale)
    local f = self.frame
    if not f then return end
    scale = math.max(MIN_SCALE, math.min(MAX_SCALE, scale))
    local left, top = f:GetLeft(), f:GetTop()
    local oldEff = f:GetEffectiveScale()
    f:SetScale(scale)
    if left and top and oldEff then
        local newEff = f:GetEffectiveScale()
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * oldEff / newEff, top * oldEff / newEff)
    end
    if ns.db then ns.db.settings.frameScale = scale end
    self:SavePosition()
    if self.OnScaleChanged then self:OnScaleChanged(scale) end
end

function Suite:CreateResizeGrip(f)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel((f:GetFrameLevel() or 1) + 30)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Ziehen: Fenster größer/kleiner\nRechtsklick: Originalgröße", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", GameTooltip_Hide)
    grip:RegisterForClicks("RightButtonUp")
    grip:SetScript("OnClick", function() Suite:SetFrameScale(1) end)
    grip:SetScript("OnMouseDown", function(b, button)
        if button ~= "LeftButton" then return end
        local cx, cy = GetCursorPosition()
        b.drag = {
            cx = cx, cy = cy, scale = f:GetScale(),
            w = f:GetWidth() * f:GetEffectiveScale(), h = f:GetHeight() * f:GetEffectiveScale(),
        }
        b:SetScript("OnUpdate", function(self)
            local d = self.drag
            if not d then return end
            local x, y = GetCursorPosition()
            -- Ziehen nach rechts/unten = groesser; Mittelwert aus Breite und Hoehe
            local fw = (d.w + (x - d.cx)) / d.w
            local fh = (d.h + (d.cy - y)) / d.h
            local factor = (fw + fh) / 2
            local ns2 = d.scale * factor
            if math.abs(ns2 - f:GetScale()) > 0.005 then Suite:SetFrameScale(ns2) end
        end)
    end)
    grip:SetScript("OnMouseUp", function(b)
        b.drag = nil
        b:SetScript("OnUpdate", nil)
        Suite:SavePosition()
    end)
    self.grip = grip
end

-- hoechste Frame-Ebene unterhalb von f (damit Reiter sicher oben liegen)
function Suite:HighestLevel(f)
    local max = f:GetFrameLevel() or 1
    local function walk(fr, depth)
        if depth > 6 or not fr.GetChildren then return end
        for _, c in ipairs({ fr:GetChildren() }) do
            local lv = c.GetFrameLevel and c:GetFrameLevel()
            if type(lv) == "number" and lv > max then max = lv end
            walk(c, depth + 1)
        end
    end
    walk(f, 0)
    return max
end

function Suite:RegisterModule(mod)
    self.modules[#self.modules + 1] = mod
end

function Suite:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "CBASFrame", UIParent, "BasicFrameTemplateWithInset")
    self.frame = f
    f:SetSize(WIDTH, HEIGHT + TAB_H)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    self:MakeDraggable(f)
    f:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, (ns.db and ns.db.settings.frameScale) or 1)))
    self:RestorePosition()
    self:CreateResizeGrip(f)
    tinsert(UISpecialFrames, "CBASFrame")

    -- eigene Griffleiste ueber dem Titel (falls die Vorlage Klicks abfaengt)
    local grip = CreateFrame("Frame", nil, f)
    grip:SetPoint("TOPLEFT", 4, -1)
    grip:SetPoint("TOPRIGHT", -28, -1)   -- Schliessen-Knopf frei lassen
    grip:SetHeight(22)
    grip:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
    self:MakeDraggable(grip)

    local title = type(f.TitleText) == "table" and f.TitleText or nil
    if not title then
        title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText("Craphunts Blacklisted Addon Suite  |cff888888" .. (ns.VERSION or "") .. "|r")

    -- Einstellungen (Zahnrad) immer zuletzt
    if not self.settingsAdded then
        self.settingsAdded = true
        self:RegisterSettings()
    end

    -- Reiterleiste
    local x = 12
    self.byId = {}
    for _, mod in ipairs(self.modules) do self.byId[mod.id] = mod end
    for i, mod in ipairs(self.modules) do
        if not mod.hidden then
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetText(mod.name)
            local w = math.max(90, (b:GetFontString() and b:GetFontString():GetStringWidth() or 60) + 30)
            b:SetSize(w, 22)
            b:SetPoint("TOPLEFT", x, -28)
            b:SetScript("OnClick", function() Suite:Select(Suite.lastSub and Suite.lastSub[mod.id] or mod.id) end)
            x = x + w + 4
            self.tabs[mod.id] = b
        end

        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", 0, -TAB_H)
        p:SetSize(WIDTH, HEIGHT)
        self:MakeDraggable(p)   -- leere Flaechen im Reiter zum Verschieben nutzen
        -- oberen Streifen (dort liegen die Reiter-Knoepfe) fuer Klicks freihalten
        if p.SetHitRectInsets then p:SetHitRectInsets(0, 0, 26, 0) end
        p:Hide()
        self.panels[mod.id] = p
        mod.create(p)
    end
    -- Reiter-Knoepfe ueber die Inhaltsbereiche legen: die Bereiche fangen Mausklicks
    -- (zum Verschieben) ab und liegen sonst ueber den Knoepfen
    -- Unteransichten (z.B. GScout: Gilden | Gildenlose) als kleine Knoepfe hinter den Reitern
    self.subBtns = {}
    local sx = x + 16
    for _, mod in ipairs(self.modules) do
        if mod.parent and self.byId[mod.parent] then
            local list = self.subBtns[mod.parent]
            if not list then
                list = {}
                self.subBtns[mod.parent] = list
                local pm = self.byId[mod.parent]
                local b0 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
                b0:SetSize(80, 20); b0:SetPoint("TOPLEFT", sx, -29); b0:SetText(pm.subName or pm.name)
                b0:SetScript("OnClick", function() Suite:Select(pm.id) end)
                b0.id = pm.id
                list[#list + 1] = b0
                sx = sx + 82
            end
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(90, 20); b:SetPoint("TOPLEFT", sx, -29); b:SetText(mod.name)
            b:SetScript("OnClick", function() Suite:Select(mod.id) end)
            b.id = mod.id
            list[#list + 1] = b
            sx = sx + 92
        end
    end
    -- Einstellungen: Zahnrad in der Titelleiste
    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(18, 18)
    gear:SetPoint("TOPRIGHT", -30, -3)
    gear:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
    gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    gear:SetScript("OnClick", function()
        if Suite.current == "settings" then Suite:Select(Suite.beforeSettings) else Suite:Select("settings") end
    end)
    gear:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Einstellungen")
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", GameTooltip_Hide)
    self.gear = gear
    if ns.Version then ns.Version.UpdateBadge() end

    local top = self:HighestLevel(f) + 5
    for _, b in pairs(self.tabs) do b:SetFrameLevel(top) end
    for _, list in pairs(self.subBtns) do for _, b in ipairs(list) do b:SetFrameLevel(top) end end
    gear:SetFrameLevel(top + 2)
    if self.grip then self.grip:SetFrameLevel(top) end
    -- Layer-Anzeige oben rechts (in allen Reitern sichtbar)
    local lh = CreateFrame("Frame", nil, f)
    lh:SetPoint("TOPRIGHT", -14, -28)
    lh:SetSize(330, 22)
    lh:SetFrameLevel(top)
    lh:EnableMouse(true)
    local lt = lh:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lt:SetAllPoints()
    lt:SetJustifyH("RIGHT")
    self.layerText = lt
    lh:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
        GameTooltip:AddLine("Layer & Welt", 1, 0.82, 0)
        local L = ns.Layer
        GameTooltip:AddLine("Welt: " .. L.World(), 1, 1, 1)
        if L.cur then
            GameTooltip:AddLine(string.format("Layer %s in %s (ID %s)", (L.Label(L.cur)), L.cur.zone, L.cur.key), 1, 1, 1)
        else
            GameTooltip:AddLine("Layer erscheint, sobald du einen NPC anvisierst oder mit der Maus berührst.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine("/who und Scans sehen nur Spieler auf deinem Layer.", 0.6, 0.6, 0.6, true)
        local lines = L:PeerLines()
        if #lines > 0 then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Layer-Partner", 1, 0.82, 0)
            for _, x in ipairs(lines) do GameTooltip:AddLine(x, 1, 1, 1, true) end
        else
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Layer-Partner eintragen: Einstellungen oder /crap partner add <Name>", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    lh:SetScript("OnLeave", GameTooltip_Hide)
    self:UpdateHeader()
    if C_Timer.NewTicker then C_Timer.NewTicker(3, function() pcall(Suite.UpdateHeader, Suite) end) end

    -- Trennlinie unter den Reitern
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 1, 1, 0.12)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 10, -TAB_H - 25)
    line:SetPoint("TOPRIGHT", -10, -TAB_H - 25)

    self:Select(ns.db and ns.db.settings.lastTab or (self.modules[1] and self.modules[1].id))
    f:Hide()
end

function Suite:UpdateHeader()
    if not self.layerText or not ns.Layer then return end
    if self.frame and not self.frame:IsShown() then return end
    self.layerText:SetText(ns.Layer:HeaderText() .. "  |cff888888· " .. ns.Layer.World() .. "|r")
end

function Suite:Select(id)
    if not self.panels[id] then id = self.modules[1] and self.modules[1].id end
    if not id then return end
    if id ~= "settings" then self.beforeSettings = id end
    self.current = id
    if ns.db then ns.db.settings.lastTab = id end
    local mod = self.byId and self.byId[id]
    local tabId = (mod and mod.parent) or id
    self.lastSub = self.lastSub or {}
    if self.subBtns and self.subBtns[tabId] then self.lastSub[tabId] = id end
    for mid, p in pairs(self.panels) do p:SetShown(mid == id) end
    for mid, b in pairs(self.tabs) do
        if mid == tabId then b:LockHighlight() else b:UnlockHighlight() end
    end
    for pid, list in pairs(self.subBtns or {}) do
        for _, b in ipairs(list) do
            b:SetShown(pid == tabId)
            if b.id == id then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    for _, mod in ipairs(self.modules) do
        if mod.id == id and mod.onShow then mod.onShow(self.panels[id]) end
    end
end

-- Fenster oeffnen/schliessen; mit id direkt einen Reiter oeffnen
function Suite:Toggle(id)
    self:Create()
    if id then
        self.frame:Show()
        self:Select(id)
        return
    end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:Select(self.current)
    end
end

---------------------------------------------------------------------------
-- Modul: Einstellungen
---------------------------------------------------------------------------
local SETTINGS = {
    { header = "GScout - Datensammlung" },
    { key = "chatScan", label = "Chat nach Gildenwerbung durchsuchen" },
    { key = "nameplates", label = "Namensplaketten mitlesen" },
    { key = "inspect", label = "Gildenmitglieder beim Anvisieren inspizieren (echte Gildengröße, Itemlevel)" },
    { key = "zoneScanDungeons", label = "Instanz-Scan auch für Dungeons (sonst nur Raids)" },
    { key = "scanCapitals", label = "60er-Scan auch in Hauptstädten" },
    { header = "GScout - Austausch" },
    { key = "sync", label = "Daten mit anderen CBAS-Nutzern in der Gruppe tauschen" },
    { header = "Geierwacht - Loot-Kontrolle" },
    { key = "lootWatch", label = "Bedarf-Würfe und Beute in Gruppe/Raid prüfen" },
    { key = "lootAlerts", label = "Chat-Warnung bei unpassendem Bedarf-Wurf" },
    { key = "lootSpecInspect", label = "Gruppenmitglieder inspizieren (Spezialisierung = Mainspec)" },
    { key = "lootMSOS", label = "Regel MS>OS: Mainspec-Bedarf auf Offspec-Beute als fragwürdig werten" },
    { header = "Flipper" },
    { key = "flipTooltip", label = "AH-/Händler-Flip-Info im Gegenstands-Tooltip" },
    { key = "flipAHHelp", label = "Kaufhilfe neben dem Auktionshaus (Menge, Kosten, Gewinn)" },
    { key = "flipAutoVendor", label = "Markierte Händler-Flips beim Händler automatisch verkaufen" },
    { header = "GScout - Anzeige & Meldungen" },
    { key = "tooltip", label = "Gildeninfo im Spieler-Tooltip" },
    { key = "notifyRecruit", label = "Chat-Meldung bei neu entdeckter rekrutierender Gilde" },
    { key = "notifyNew", label = "Chat-Meldung bei jeder neuen Gilde" },
    { key = "notifySeeker", label = "Chat-Meldung, wenn jemand im Chat eine Gilde sucht" },
}

local function CreateSettings(p)
    local y = -40
    local checks = {}
    for _, s in ipairs(SETTINGS) do
        if s.header then
            local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            h:SetPoint("TOPLEFT", 24, y)
            h:SetText(s.header)
            y = y - 22
        else
            local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
            cb:SetSize(24, 24)
            cb:SetPoint("TOPLEFT", 30, y)
            local fs = (type(cb.Text) == "table" and cb.Text) or (type(cb.text) == "table" and cb.text) or nil
            if not fs then
                fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            end
            fs:SetFontObject("GameFontHighlight")
            fs:SetText(s.label)
            cb:SetScript("OnClick", function(self)
                ns.db.settings[s.key] = self:GetChecked() and true or false
                ns.RefreshUI()
            end)
            cb.key = s.key
            checks[#checks + 1] = cb
            y = y - 22
        end
    end

    y = y - 12
    local info = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    info:SetPoint("TOPLEFT", 24, y)
    info:SetJustifyH("LEFT")
    info:SetText("Befehle: /crap (Fenster)  ·  /crap help (alle Befehle)  ·  /crap settings (diese Seite)  ·  /crap reset (Fenster zur Mitte)\nVerschieben: an jeder freien Stelle ziehen  ·  Größe: Griff unten rechts ziehen (Rechtsklick = Originalgröße)")
    p.info = info
    if ns.Version then ns.Version.BuildSettings(p) end
    if ns.ChatFlags then ns.ChatFlags.BuildSettings(p) end

    local purge = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    purge:SetSize(240, 22)
    purge:SetPoint("TOPLEFT", 24, y - 36)
    purge:SetText("Alte Gilden aufräumen (60 Tage)")
    purge:SetScript("OnClick", function() ns.Purge(60) end)

    local reset = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    reset:SetSize(200, 22)
    reset:SetPoint("LEFT", purge, "RIGHT", 8, 0)
    reset:SetText("Fensterposition zurücksetzen")
    reset:SetScript("OnClick", function() Suite:ResetPosition() end)

    local pl = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pl:SetPoint("TOPLEFT", 24, y - 70)
    pl:SetText("Layer-Partner:")
    local pe = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    pe:SetSize(420, 20)
    pe:SetPoint("LEFT", pl, "RIGHT", 12, 0)
    pe:SetAutoFocus(false)
    pe:SetScript("OnEscapePressed", pe.ClearFocus)
    pe:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local list = {}
        for n in (self:GetText() or ""):gmatch("[^,%s]+") do list[#list + 1] = n end
        ns.db.settings.layerPartners = {}
        for _, n in ipairs(list) do ns.Layer.AddPartner(n) end
    end)
    pe:SetScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText("Namen mit Komma trennen, dann Enter.\nDie Partner müssen in deiner Freundesliste stehen und CBAS haben.\nIhr seht dann gegenseitig, auf welchem Layer ihr gerade seid.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    pe:SetScript("OnLeave", GameTooltip_Hide)
    p.partnerEdit = pe

    local sizeLbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLbl:SetPoint("LEFT", reset, "RIGHT", 24, 0)
    p.sizeLbl = sizeLbl
    local minus = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    minus:SetSize(26, 22)
    minus:SetPoint("LEFT", sizeLbl, "RIGHT", 8, 0)
    minus:SetText("-")
    minus:SetScript("OnClick", function() Suite:SetFrameScale((Suite.frame:GetScale() or 1) - 0.1) end)
    local plus = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    plus:SetSize(26, 22)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    plus:SetText("+")
    plus:SetScript("OnClick", function() Suite:SetFrameScale((Suite.frame:GetScale() or 1) + 0.1) end)

    local stats = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stats:SetPoint("TOPLEFT", 24, y - 96)
    stats:SetJustifyH("LEFT")
    p.stats = stats
    p.checks = checks
end

local function UpdateSizeLabel(p)
    if p and p.sizeLbl and Suite.frame then
        p.sizeLbl:SetText(string.format("Fenstergröße: %d%%", math.floor((Suite.frame:GetScale() or 1) * 100 + 0.5)))
    end
end
function Suite:OnScaleChanged() UpdateSizeLabel(self.panels and self.panels.settings) end

local function ShowSettings(p)
    UpdateSizeLabel(p)
    if ns.Version then ns.Version.UpdateSettings() end
    if ns.ChatFlags then ns.ChatFlags.UpdateSettings() end
    if p.partnerEdit and not p.partnerEdit:HasFocus() then
        local names = {}
        for _, f in ipairs((ns.Layer and ns.Layer.Partners()) or {}) do names[#names + 1] = ns.SplitName(f) end
        p.partnerEdit:SetText(table.concat(names, ", "))
    end
    for _, cb in ipairs(p.checks) do cb:SetChecked(ns.db.settings[cb.key] and true or false) end
    local g, m = 0, 0
    for _, gg in pairs(ns.db.guilds) do
        g = g + 1
        m = m + (gg.memberCount or 0)
    end
    p.stats:SetText(string.format("Datenbank: %d Gilden, %d Spieler  ·  Region: %s  ·  Realm: %s",
        g, m, ns.region or "?", tostring(ns.MyRealm())))
end

-- wird nach UI.lua registriert, damit GScout der erste Reiter ist
function Suite:RegisterSettings()
    self:RegisterModule({ id = "settings", name = "Einstellungen", hidden = true, create = CreateSettings, onShow = ShowSettings })
end
