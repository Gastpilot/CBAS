-- CBAS (Craphunts Blacklisted Addon Suite) - Hauptfenster
-- Aufbau: links Seitenleiste (Module + Unteransichten), oben Kopfzeile (Titel, Layer, Schliessen),
-- rechts der Inhaltsbereich des gewaehlten Moduls.
-- Jedes Modul meldet sich mit ns.Suite:RegisterModule({ id, name, icon, desc, parent, create, onShow }) an.
local ADDON, ns = ...

local Suite = { modules = {}, panels = {}, tabs = {} }
ns.Suite = Suite

local WIDTH, HEIGHT = 860, 545   -- Inhaltsbereich je Modul (Module bauen ab y = -30)
local SIDE = 176                 -- Breite der Seitenleiste
local HEAD = 52                  -- Hoehe der Kopfzeile
local PTOP = 32                  -- Oberkante der Inhaltsbereiche; ihr oberer Streifen (30 px) liegt unter der Kopfzeile
local unpack = unpack or table.unpack
Suite.SIDE, Suite.HEAD = SIDE, HEAD

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
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
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

-- Titelzeilen der Ansichten (Module koennen eigene mitbringen: mod.desc)
local DESC = {
    home = "Was gerade zählt – je nachdem, wo du bist",
    gscout = "Gilden-Datenbank: finden, vergleichen, notieren",
    gildenlos = "Spieler ohne Gilde – mögliche Rekruten",
    geier = "Loot-Kontrolle: passt der Bedarf-Wurf zur Spec?",
    cihi = "Darf ich Bedarf würfeln? Ehrliche Antwort mit Begründung",
    flipper = "Auktionshaus: kaufen, lagern, verkaufen",
    settings = "Alle Einstellungen nach Bereichen",
}
local ICONS = {
    home = "Interface\\Icons\\INV_Misc_Spyglass_02",
    gscout = "Interface\\Icons\\INV_Misc_Book_09",
    geier = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    flipper = "Interface\\Icons\\INV_Misc_Coin_01",
    settings = "Interface\\Icons\\INV_Misc_Gear_01",
}

---------------------------------------------------------------------------
-- Seitenleiste
---------------------------------------------------------------------------
local function NavPaint(b)
    local T = ns.T
    local on = b.active
    local hover = b.hover
    b.bar:SetShown(on and true or false)
    b.bg:SetVertexColor(1, 1, 1, on and 0.06 or (hover and 0.035 or 0))
    local c = (on or hover) and T.C.text or T.C.dim
    b.label:SetTextColor(c[1], c[2], c[3])
    if b.icon then b.icon:SetDesaturated(not on and not hover); b.icon:SetAlpha(on and 1 or 0.75) end
end

local function NavItem(parent, text, icon, sub)
    local T = ns.T
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(SIDE - 16, sub and 24 or 30)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(T.WHITE)
    bg:SetAllPoints()
    b.bg = bg
    local bar = b:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(T.WHITE)
    bar:SetVertexColor(T.C.accent[1], T.C.accent[2], T.C.accent[3], 1)
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 0, sub and -4 or 0)
    bar:SetPoint("BOTTOMLEFT", 0, sub and 4 or 0)
    b.bar = bar
    local x = 12
    if icon then
        local ic = b:CreateTexture(nil, "ARTWORK")
        ic:SetSize(18, 18)
        ic:SetPoint("LEFT", 12, 0)
        ic:SetTexture(icon)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.icon = ic
        x = 40
    elseif sub then
        local dot = b:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(T.WHITE)
        dot:SetSize(4, 4)
        dot:SetPoint("LEFT", 22, 0)
        dot:SetVertexColor(1, 1, 1, 0.25)
        b.dot = dot
        x = 40
    end
    local fs = b:CreateFontString(nil, "OVERLAY", sub and "GameFontHighlightSmall" or "GameFontHighlight")
    fs:SetPoint("LEFT", x, 0)
    fs:SetPoint("RIGHT", -8, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    fs:SetText(text)
    b.label = fs
    b.SetText = function(s, t) s.label:SetText(t) end
    b.GetText = function(s) return s.label:GetText() end
    b:SetScript("OnEnter", function(s) s.hover = true; NavPaint(s) end)
    b:SetScript("OnLeave", function(s) s.hover = false; NavPaint(s) end)
    b.LockHighlight = function(s) s.active = true; NavPaint(s) end
    b.UnlockHighlight = function(s) s.active = false; NavPaint(s) end
    NavPaint(b)
    return b
end

Suite.NavItem = NavItem

function Suite:BuildSidebar(f)
    local T = ns.T
    local side = CreateFrame("Frame", nil, f)
    side:SetPoint("TOPLEFT", 0, 0)
    side:SetPoint("BOTTOMLEFT", 0, 0)
    side:SetWidth(SIDE)
    self:MakeDraggable(side)
    self.side = side
    local bg = side:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(T.WHITE)
    bg:SetAllPoints()
    bg:SetVertexColor(unpack(T.C.side))
    local sep = side:CreateTexture(nil, "BORDER")
    sep:SetTexture(T.WHITE)
    sep:SetVertexColor(unpack(T.C.line))
    sep:SetWidth(1)
    sep:SetPoint("TOPRIGHT")
    sep:SetPoint("BOTTOMRIGHT")

    -- Marke: Einhorn + CBAS + Version
    local logo = side:CreateTexture(nil, "ARTWORK")
    logo:SetSize(30, 30)
    logo:SetPoint("TOPLEFT", 14, -11)
    logo:SetTexture("Interface\\AddOns\\" .. ADDON .. "\\Media\\Unicorn")
    local name = side:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", logo, "TOPRIGHT", 9, -1)
    name:SetText("CBAS")
    name:SetTextColor(1, 1, 1)
    local ver = side:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ver:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    ver:SetText("Version " .. (ns.VERSION or ""))
    ver:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    local brand = CreateFrame("Frame", nil, side)
    brand:SetPoint("TOPLEFT", 6, -6)
    brand:SetSize(SIDE - 12, 40)
    self:MakeDraggable(brand)
    brand:HookScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Craphunts Blacklisted Addon Suite", 1, 1, 1)
        GameTooltip:AddLine("Ziehen: Fenster verschieben  ·  Esc: schließen", T.C.dim[1], T.C.dim[2], T.C.dim[3])
        GameTooltip:Show()
    end)
    brand:HookScript("OnLeave", GameTooltip_Hide)

    -- Module mit eingerueckten Unteransichten
    local subsOf = {}
    for _, mod in ipairs(self.modules) do
        if mod.parent and self.byId[mod.parent] then
            subsOf[mod.parent] = subsOf[mod.parent] or {}
            table.insert(subsOf[mod.parent], mod)
        end
    end
    local y = -64
    self.subBtns = {}
    for _, mod in ipairs(self.modules) do
        if not mod.parent and mod.id ~= "settings" then
            local b = NavItem(side, mod.name, mod.icon or ICONS[mod.id])
            b:SetPoint("TOPLEFT", 8, y)
            b:SetScript("OnClick", function() Suite:Select(Suite.lastSub and Suite.lastSub[mod.id] or mod.id) end)
            b.id = mod.id
            self.tabs[mod.id] = b
            y = y - 31
            local subs = subsOf[mod.id]
            if subs then
                local list = {}
                self.subBtns[mod.id] = list
                local b0 = NavItem(side, mod.subName or mod.name, nil, true)
                b0:SetPoint("TOPLEFT", 8, y)
                b0:SetScript("OnClick", function() Suite:Select(mod.id) end)
                b0.id = mod.id
                list[1] = b0
                y = y - 24
                for _, sm in ipairs(subs) do
                    local sb = NavItem(side, sm.name, nil, true)
                    sb:SetPoint("TOPLEFT", 8, y)
                    sb:SetScript("OnClick", function() Suite:Select(sm.id) end)
                    sb.id = sm.id
                    list[#list + 1] = sb
                    y = y - 24
                end
                y = y - 6
            end
        end
    end

    -- unten: Einstellungen (+ gruener Punkt bei neuer Version)
    local gear = NavItem(side, "Einstellungen", ICONS.settings)
    gear:SetPoint("BOTTOMLEFT", 8, 12)
    gear:SetScript("OnClick", function()
        if Suite.current == "settings" then Suite:Select(Suite.beforeSettings) else Suite:Select("settings") end
    end)
    gear.id = "settings"
    self.gear = gear
    local hint = side:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", gear, "TOPLEFT", 12, 8)
    hint:SetPoint("RIGHT", side, "RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3], 0.7)
    hint:SetText("/crap help · alle Befehle")
end

---------------------------------------------------------------------------
-- Kopfzeile: Titel + Beschreibung, Layer-Anzeige, Schliessen
---------------------------------------------------------------------------
function Suite:BuildHeader(f)
    local T = ns.T
    local head = CreateFrame("Frame", nil, f)
    head:SetPoint("TOPLEFT", SIDE, 0)
    head:SetPoint("TOPRIGHT", 0, 0)
    head:SetHeight(HEAD)
    self:MakeDraggable(head)
    self.head = head
    local bg = head:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetTexture(T.WHITE)
    bg:SetAllPoints()
    bg:SetVertexColor(unpack(T.C.head))
    local line = head:CreateTexture(nil, "BORDER")
    line:SetTexture(T.WHITE)
    line:SetVertexColor(unpack(T.C.line))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")

    local title = head:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -10)
    title:SetTextColor(1, 1, 1)
    self.titleText = title
    local desc = head:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    desc:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    self.descText = desc

    local close = CreateFrame("Button", nil, head)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -12, -13)
    local ct = close:CreateTexture(nil, "ARTWORK")
    ct:SetTexture("Interface\\Buttons\\UI-StopButton")
    ct:SetAllPoints()
    ct:SetVertexColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    close:SetScript("OnEnter", function() ct:SetVertexColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() ct:SetVertexColor(T.C.dim[1], T.C.dim[2], T.C.dim[3]) end)
    close:SetScript("OnClick", function() f:Hide() end)
    self.closeBtn = close

    -- Layer-Anzeige (in allen Ansichten sichtbar)
    local lh = CreateFrame("Frame", nil, head)
    lh:SetPoint("RIGHT", close, "LEFT", -14, 0)
    lh:SetSize(360, 22)
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
            GameTooltip:AddLine("Layer-Partner eintragen: Einstellungen > Layer oder /crap partner add <Name>", 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    lh:SetScript("OnLeave", GameTooltip_Hide)
end

function Suite:Create()
    if self.frame then return end
    local T = ns.T
    local f = CreateFrame("Frame", "CBASFrame", UIParent)
    self.frame = f
    f:SetSize(SIDE + WIDTH, PTOP + HEIGHT)
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    self:MakeDraggable(f)
    f:SetScale(math.max(MIN_SCALE, math.min(MAX_SCALE, (ns.db and ns.db.settings.frameScale) or 1)))
    self:RestorePosition()
    tinsert(UISpecialFrames, "CBASFrame")
    -- Flaeche, feiner Rand, weicher Schatten
    T.Box(f, T.C.bg, { 1, 1, 1, 0.10 })
    local sh = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    sh:SetTexture(T.WHITE)
    sh:SetVertexColor(0, 0, 0, 0.45)
    sh:SetPoint("TOPLEFT", -4, 4)
    sh:SetPoint("BOTTOMRIGHT", 4, -4)
    local sh2 = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    sh2:SetTexture(T.WHITE)
    sh2:SetVertexColor(0, 0, 0, 0.25)
    sh2:SetPoint("TOPLEFT", -9, 9)
    sh2:SetPoint("BOTTOMRIGHT", 9, -9)

    -- Einstellungen immer zuletzt
    if not self.settingsAdded then
        self.settingsAdded = true
        self:RegisterSettings()
    end
    self.byId = {}
    for _, mod in ipairs(self.modules) do self.byId[mod.id] = mod end

    -- Inhaltsbereiche: oberer Streifen ragt in die Kopfzeile und bleibt klickfrei
    for _, mod in ipairs(self.modules) do
        local p = CreateFrame("Frame", nil, f)
        p:SetPoint("TOPLEFT", SIDE, -PTOP)
        p:SetSize(WIDTH, HEIGHT)
        self:MakeDraggable(p)
        if p.SetHitRectInsets then p:SetHitRectInsets(0, 0, 30, 0) end
        p:Hide()
        self.panels[mod.id] = p
        mod.create(p)
        if T.Skin then pcall(T.Skin, p) end
        -- spaeter erzeugte Elemente (Listenzeilen, Menues) beim Anzeigen nachziehen
        local old = p:GetScript("OnShow")
        p:SetScript("OnShow", function(s, ...)
            if old then old(s, ...) end
            pcall(T.Skin, s)
        end)
    end

    self:BuildSidebar(f)
    self:BuildHeader(f)
    self:CreateResizeGrip(f)
    if ns.Version then ns.Version.UpdateBadge() end

    -- Seitenleiste und Kopf ueber die Inhaltsbereiche legen
    local top = self:HighestLevel(f) + 5
    self.side:SetFrameLevel(top)
    self.head:SetFrameLevel(top)
    local function raise(fr, lv)
        for _, c in ipairs({ fr:GetChildren() }) do c:SetFrameLevel(lv); raise(c, lv + 1) end
    end
    raise(self.side, top + 1)
    raise(self.head, top + 1)
    if self.grip then self.grip:SetFrameLevel(top + 4) end

    self:UpdateHeader()
    if C_Timer.NewTicker then C_Timer.NewTicker(3, function() pcall(Suite.UpdateHeader, Suite) end) end

    local last = ns.db and ns.db.settings.lastTab
    self:Select((last and self.panels[last]) and last or "home")
    f:Hide()
end

function Suite:UpdateHeader()
    if not self.layerText or not ns.Layer then return end
    if self.frame and not self.frame:IsShown() then return end
    self.layerText:SetText(ns.Layer:HeaderText() .. "  |cff8f949f· " .. ns.Layer.World() .. "|r")
end

local function FirstModule(self)
    for _, m in ipairs(self.modules) do if m.id ~= "settings" then return m.id end end
end

function Suite:Select(id)
    if not self.panels[id] then id = (self.panels.home and "home") or FirstModule(self) end
    if not id then return end
    if id ~= "settings" then self.beforeSettings = id end
    self.current = id
    if ns.db then ns.db.settings.lastTab = id end
    local mod = self.byId and self.byId[id]
    local tabId = (mod and mod.parent) or id
    self.lastSub = self.lastSub or {}
    if self.subBtns and self.subBtns[tabId] then self.lastSub[tabId] = id end
    for mid, p in pairs(self.panels) do p:SetShown(mid == id) end
    -- Seitenleiste: Gruppe markiert, wenn sie keine Unteransichten hat; sonst die Unteransicht
    for mid, b in pairs(self.tabs) do
        local hasSubs = self.subBtns and self.subBtns[mid]
        if mid == tabId and not hasSubs then b:LockHighlight() else b:UnlockHighlight() end
        if b.label and mid == tabId and hasSubs then b.label:SetTextColor(1, 1, 1) end
    end
    for pid, list in pairs(self.subBtns or {}) do
        for _, b in ipairs(list) do
            b:SetShown(true)
            if b.id == id then b:LockHighlight() else b:UnlockHighlight() end
        end
    end
    if self.gear then
        if id == "settings" then self.gear:LockHighlight() else self.gear:UnlockHighlight() end
    end
    -- Kopfzeile
    if self.titleText then
        local parent = mod and mod.parent and self.byId[mod.parent]
        local name = mod and mod.name or id
        if parent then
            self.titleText:SetText(parent.name .. "  |cff8f949f›|r  " .. name)
        elseif self.subBtns and self.subBtns[id] then
            self.titleText:SetText(name .. "  |cff8f949f›|r  " .. (mod.subName or name))
        else
            self.titleText:SetText(name)
        end
        self.descText:SetText((mod and mod.desc) or DESC[id] or "")
    end
    for _, m in ipairs(self.modules) do
        if m.id == id and m.onShow then m.onShow(self.panels[id]) end
    end
end

-- Fenster oeffnen/schliessen; mit id direkt eine Ansicht oeffnen
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

-- Einstellungen kommen aus UI/Settings.lua
function Suite:RegisterSettings()
    self:RegisterModule({ id = "settings", name = "Einstellungen", hidden = true,
        create = function(p) ns.Settings.Create(p) end, onShow = function(p) ns.Settings.Show(p) end })
end
