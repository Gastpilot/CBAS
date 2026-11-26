-- CBAS - Mage-Dienste: Oberflaeche
-- Oben: der naechste Schritt mit grossem pinken Knopf (= Autopilot-Taste).
-- Links: Kunden aus dem Chat (Klick waehlt, Ziel/Art umstellbar, x entfernt).
-- Rechts: Vorrat, Preise, Einnahmen heute.
local ADDON, ns = ...
local MG = ns.Mage
local UI = {}
MG.UI = UI

local ROWS, ROW_H = 7, 38
local LW = 520          -- Breite der Kundenliste
local unpack = unpack or table.unpack

local KIND_TXT = { port = "Portal", water = "Wasser", food = "Essen" }
local STATE_TXT = { new = "neu", told = "angeschrieben", invited = "eingeladen", group = "in der Gruppe", ported = "Portal steht", done = "fertig" }

local function Ago(t)
    local d = time() - (t or time())
    if d < 60 then return d .. " s" end
    return math.floor(d / 60) .. " Min."
end

local function KeyText()
    local k = GetBindingKey and GetBindingKey("CLICK CBASMageButton:LeftButton")
    return k and ("Taste: " .. k) or "Taste belegen: Tastenbelegung > AddOns > CBAS"
end

---------------------------------------------------------------------------
-- sichere Taste ueber den grossen Knopf legen (nur ausserhalb des Kampfes)
---------------------------------------------------------------------------
local pendingDock
local function Dock(show)
    local b = MG.button
    if not b then return end
    if InCombatLockdown and InCombatLockdown() then pendingDock = show return end
    pendingDock = nil
    b:ClearAllPoints()
    if show and UI.go then
        b:SetAllPoints(UI.go)
        b:SetFrameStrata("DIALOG")
    else
        b:SetSize(1, 1)
        b:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -50, 50)
    end
end
UI.Dock = Dock

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function MakeRow(p, i)
    local T = ns.T
    local C = T.C
    local r = CreateFrame("Button", nil, p)
    r:SetSize(LW, ROW_H - 2)
    r:SetPoint("TOPLEFT", 16, -196 - (i - 1) * ROW_H)
    local bg = r:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(T.WHITE)
    bg:SetAllPoints()
    bg:SetVertexColor(1, 1, 1, 0)
    r.bg = bg
    local bar = r:CreateTexture(nil, "ARTWORK")
    bar:SetTexture(T.WHITE)
    bar:SetWidth(3)
    bar:SetPoint("TOPLEFT", 0, -4)
    bar:SetPoint("BOTTOMLEFT", 0, 4)
    r.bar = bar
    local name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("TOPLEFT", 12, -5)
    name:SetWidth(200)
    name:SetJustifyH("LEFT")
    r.name = name
    local what = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    what:SetPoint("TOPLEFT", 220, -5)
    what:SetWidth(180)
    what:SetJustifyH("LEFT")
    r.what = what
    local msg = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    msg:SetPoint("TOPLEFT", 12, -21)
    msg:SetPoint("RIGHT", -40, 0)
    msg:SetJustifyH("LEFT")
    msg:SetWordWrap(false)
    msg:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    r.msg = msg
    local state = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    state:SetPoint("TOPRIGHT", -40, -6)
    state:SetJustifyH("RIGHT")
    r.state = state
    local x = T.Button(r, "x", 24, 22, "quiet")
    x:SetPoint("RIGHT", -6, 0)
    x:SetScript("OnClick", function() if r.c then MG.Remove(r.c) end end)
    T.Tip(x, "Kunde entfernen")
    r.x = x
    local line = r:CreateTexture(nil, "BORDER")
    line:SetTexture(T.WHITE)
    line:SetVertexColor(unpack(C.line))
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 0, -1)
    line:SetPoint("BOTTOMRIGHT", 0, -1)
    r:SetScript("OnClick", function() if r.c then MG.Select(r.c) end end)
    r:SetScript("OnEnter", function(s)
        if not s.sel then s.bg:SetVertexColor(1, 1, 1, 0.04) end
        if s.c and s.c.msg then
            GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.c.full, 1, 1, 1)
            GameTooltip:AddLine(s.c.msg, C.dim[1], C.dim[2], C.dim[3], true)
            GameTooltip:AddLine((s.c.src or "") .. " · vor " .. Ago(s.c.t), C.dim[1], C.dim[2], C.dim[3])
            GameTooltip:Show()
        end
    end)
    r:SetScript("OnLeave", function(s)
        if not s.sel then s.bg:SetVertexColor(1, 1, 1, 0) end
        GameTooltip_Hide()
    end)
    r:Hide()
    return r
end

-- Preisfeld in Gold (Komma oder Punkt erlaubt)
local function MoneyEdit(p, label, key, y, isCount)
    local T = ns.T
    local lb = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lb:SetPoint("TOPLEFT", 14, y)
    lb:SetText(label)
    local e = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    e:SetSize(70, 20)
    e:SetPoint("TOPRIGHT", isCount and -30 or -30, y + 4)
    e:SetAutoFocus(false)
    e:SetJustifyH("RIGHT")
    local unit = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    unit:SetPoint("LEFT", e, "RIGHT", 4, 0)
    unit:SetText(isCount and "" or "g")
    local function Load()
        local v = MG.db()[key]
        if isCount then e:SetText(tostring(v)) else e:SetText((tostring(v / 10000):gsub("%.", ","))) end
    end
    local function Save()
        local txt = (e:GetText() or ""):gsub(",", ".")
        local v = tonumber(txt)
        if v and v >= 0 then
            if isCount then MG.db()[key] = math.max(1, math.min(6, math.floor(v))) else MG.db()[key] = math.floor(v * 10000 + 0.5) end
        end
        Load()
        MG.Changed()
    end
    e:SetScript("OnEnterPressed", function(s) s:ClearFocus() Save() end)
    e:SetScript("OnEditFocusLost", Save)
    e:SetScript("OnEscapePressed", function(s) Load() s:ClearFocus() end)
    e.Load = Load
    return e
end

function UI:Create(p)
    if self.panel then return end
    self.panel = p
    local T = ns.T
    local C = T.C

    -- Naechster Schritt
    local card = T.Card(p)
    card:SetPoint("TOPLEFT", 16, -36)
    card:SetSize(828, 96)
    self.card = card
    local cap = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cap:SetPoint("TOPLEFT", 18, -12)
    cap:SetText(T.Upper("Nächster Schritt"))
    cap:SetTextColor(C.accentHi[1], C.accentHi[2], C.accentHi[3])
    local step = card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    step:SetPoint("TOPLEFT", 18, -30)
    step:SetPoint("RIGHT", -250, 0)
    step:SetJustifyH("LEFT")
    step:SetWordWrap(false)
    step:SetTextColor(1, 1, 1)
    self.step = step
    local hint = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", step, "BOTTOMLEFT", 0, -6)
    hint:SetPoint("RIGHT", -250, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    self.hint = hint
    local go = T.Button(card, "Ausführen", 210, 40, "primary")
    go:SetPoint("TOPRIGHT", -18, -16)
    -- Klicks landen auf der sicheren Taste darueber; ohne sie (Kampf, kein Magier) normaler Schritt
    go:SetScript("OnClick", function() MG.Step() end)
    self.go = go
    local key = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    key:SetPoint("TOP", go, "BOTTOM", 0, -6)
    key:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    self.key = key

    -- Kundenliste
    local h = T.Section(p, "Kunden", LW)
    h:SetPoint("TOPLEFT", 16, -150)
    local sub = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 16, -170)
    sub:SetWidth(LW)
    sub:SetJustifyH("LEFT")
    sub:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    sub:SetText("Erkannt im Chat: „wtb port“, „suche Portal nach IF“, „need water“ ... Klick wählt einen Kunden.")
    self.sub = sub
    self.rows = {}
    for i = 1, ROWS do self.rows[i] = MakeRow(p, i) end
    local empty = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 28, -210)
    empty:SetWidth(LW - 24)
    empty:SetJustifyH("LEFT")
    empty:SetText("Noch keine Kunden. Mit dem Autopilot Werbung vorbereiten – Anfragen erscheinen hier von selbst.")
    self.empty = empty

    -- Auswahl: Art und Ziel umstellen
    local selBar = CreateFrame("Frame", nil, p)
    selBar:SetPoint("TOPLEFT", 16, -196 - ROWS * ROW_H - 6)
    selBar:SetSize(LW, 26)
    self.selBar = selBar
    local kindBtn = T.Button(selBar, "Art: Portal", 110, 22)
    kindBtn:SetPoint("LEFT", 0, 0)
    kindBtn:SetScript("OnClick", function()
        local c = MG.Current()
        if not c then return end
        c.kind = (c.kind == "port" and "water") or (c.kind == "water" and "food") or "port"
        MG.Changed()
    end)
    T.Tip(kindBtn, "Was will der Kunde?", "Klick schaltet um: Portal › Wasser › Essen.")
    self.kindBtn = kindBtn
    self.destBtns = {}
    for i, pt in ipairs(MG.PORTALS) do
        local b = T.Button(selBar, pt.key:upper(), 46, 22, "quiet")
        b:SetScript("OnClick", function()
            local c = MG.Current()
            if c then c.dest, c.kind = pt.key, "port"; MG.Changed() end
        end)
        T.Tip(b, "Ziel: " .. pt.de)
        b.pt = pt
        self.destBtns[i] = b
    end

    -- rechte Spalte
    local RX, RW = 16 + LW + 20, 828 - LW - 20
    local stock = T.Card(p)
    stock:SetPoint("TOPLEFT", RX, -150)
    stock:SetSize(RW, 126)
    local sh = stock:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sh:SetPoint("TOPLEFT", 14, -10)
    sh:SetText(T.Upper("Vorrat"))
    sh:SetTextColor(C.accentHi[1], C.accentHi[2], C.accentHi[3])
    local st = stock:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    st:SetPoint("TOPLEFT", 14, -28)
    st:SetPoint("RIGHT", -14, 0)
    st:SetJustifyH("LEFT")
    st:SetSpacing(4)
    self.stockText = st

    local price = T.Card(p)
    price:SetPoint("TOPLEFT", RX, -286)
    price:SetSize(RW, 170)
    local ph = price:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ph:SetPoint("TOPLEFT", 14, -10)
    ph:SetText(T.Upper("Preise"))
    ph:SetTextColor(C.accentHi[1], C.accentHi[2], C.accentHi[3])
    self.edits = {
        MoneyEdit(price, "Portal", "portalPrice", -32),
        MoneyEdit(price, "Wasser je Stack", "waterPrice", -58),
        MoneyEdit(price, "Essen je Stack", "foodPrice", -84),
        MoneyEdit(price, "Stacks je Verkauf", "stacks", -110, true),
    }
    local lang = T.Button(price, "Texte: Deutsch", 130, 22, "quiet")
    lang:SetPoint("BOTTOMLEFT", 8, 10)
    lang:SetScript("OnClick", function()
        local m = MG.db()
        m.lang = m.lang == "en" and "de" or "en"
        MG.Changed()
    end)
    T.Tip(lang, "Sprache der Werbung und der Antworten", "Deutsch oder Englisch – im Handelschat ist oft Englisch besser.")
    self.langBtn = lang

    local earn = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    earn:SetPoint("TOPLEFT", price, "BOTTOMLEFT", 2, -12)
    earn:SetWidth(RW)
    earn:SetJustifyH("LEFT")
    self.earn = earn

    local foot = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 18, 14)
    foot:SetPoint("RIGHT", -18, 0)
    foot:SetJustifyH("LEFT")
    foot:SetTextColor(C.dim[1], C.dim[2], C.dim[3], 0.85)
    foot:SetText("Eine Taste = ein Schritt: anschreiben › einladen › handeln › annehmen › Portal › fertig. Chat-Texte landen nur in der Eingabezeile, Enter drückst du.")

    MG.OnChange(function() if UI.panel and UI.panel:IsVisible() then UI:Refresh() end end)
    p:HookScript("OnShow", function() Dock(true) end)
    p:HookScript("OnHide", function() Dock(false) end)
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
    pcall(ev.RegisterEvent, ev, "UPDATE_BINDINGS")
    ev:SetScript("OnEvent", function(_, e)
        if e == "PLAYER_REGEN_ENABLED" and pendingDock ~= nil then Dock(pendingDock) end
        if UI.panel and UI.panel:IsVisible() then UI:Refresh() end
    end)
    -- Zeiten ("vor 12 s", Werbung in ...) nur bei offener Seite auffrischen
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(2, function() if UI.panel and UI.panel:IsVisible() then pcall(UI.Refresh, UI) end end)
    end
end

function UI:Refresh()
    if not self.panel then return end
    local T = ns.T
    local C = T.C
    local m = MG.db()
    local stp = MG.Next()
    self.step:SetText(stp.text or "")
    self.hint:SetText(stp.hint or "")
    local wait = not stp.act and not stp.cast
    self.go:SetText(stp.cast and "Zaubern" or (wait and "Warten ..." or "Ausführen"))
    T.SetKind(self.go, wait and "normal" or "primary")
    self.key:SetText(KeyText())

    -- Kunden
    local cur = MG.Current()
    local list = MG.customers
    for i, r in ipairs(self.rows) do
        local c = list[i]
        r.c = c
        if c then
            r.sel = (c == cur)
            r.bg:SetVertexColor(1, 1, 1, r.sel and 0.07 or 0)
            local col = c.kind == "port" and C.accent or (c.kind == "food" and C.warn or { 0.4, 0.7, 1 })
            r.bar:SetVertexColor(col[1], col[2], col[3], r.sel and 1 or 0.6)
            r.name:SetText(c.full)
            local what = KIND_TXT[c.kind] or "?"
            if c.kind == "port" then
                local pt = c.dest and MG.PortalByKey(c.dest)
                what = "Portal › " .. (pt and pt.de or "|cffffd100Ziel?|r")
            elseif c.food and c.kind == "water" then
                what = "Wasser + Essen"
            end
            r.what:SetText(what .. "  " .. T.HEX.dim .. MG.Money(MG.Price(c)) .. "|r")
            r.msg:SetText((c.src or "") .. " · vor " .. Ago(c.t) .. " · " .. (c.msg or ""))
            r.state:SetText((c.state == "new" and T.HEX.accent or T.HEX.ok) .. (STATE_TXT[c.state] or c.state) .. "|r")
            r:Show()
        else
            r:Hide()
        end
    end
    self.empty:SetShown(#list == 0)

    -- Auswahl-Leiste
    self.selBar:SetShown(cur ~= nil)
    if cur then
        self.kindBtn:SetText("Art: " .. (KIND_TXT[cur.kind] or "?"))
        local st = MG.Stock()
        local known = {}
        for _, pt in ipairs(st.portals) do known[pt.key] = true end
        local x = 118
        for _, b in ipairs(self.destBtns) do
            local show = cur.kind == "port" and known[b.pt.key]
            b:SetShown(show and true or false)
            if show then
                b:ClearAllPoints()
                b:SetPoint("LEFT", x, 0)
                x = x + 48
                T.SetActive(b, cur.dest == b.pt.key)
            end
        end
    end

    -- Vorrat
    local st = MG.Stock()
    local lines = {}
    local function stacks(n) return string.format("%d Stk. (%.1f Stacks)", n, n / MG.STACK) end
    lines[#lines + 1] = "Wasser: " .. (st.waterSpell and stacks(st.water) or T.HEX.dim .. "noch nicht gelernt|r")
    lines[#lines + 1] = "Essen: " .. (st.foodSpell and stacks(st.food) or T.HEX.dim .. "noch nicht gelernt|r")
    local pn = {}
    for _, pt in ipairs(st.portals) do pn[#pn + 1] = pt.de end
    lines[#lines + 1] = "Portale: " .. (#pn > 0 and table.concat(pn, ", ") or T.HEX.dim .. "keine (ab Stufe 40)|r")
    if #pn > 0 then
        lines[#lines + 1] = "Runen der Portale: " .. (st.runes > 0 and st.runes or (T.HEX.bad .. "0 – beim Reagenzienhändler kaufen|r"))
    end
    self.stockText:SetText(table.concat(lines, "\n"))

    for _, e in ipairs(self.edits) do if not (e.HasFocus and e:HasFocus()) then e.Load() end end
    self.langBtn:SetText("Texte: " .. (m.lang == "en" and "Englisch" or "Deutsch"))
    local g, n = MG.Today()
    self.earn:SetText("Heute: " .. T.HEX.ok .. MG.Money(g) .. "|r aus " .. n .. (n == 1 and " Verkauf" or " Verkäufen"))
end

ns.Suite:RegisterModule({
    id = "mage",
    name = "Mage-Dienste",
    icon = "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar",
    desc = "Portale, Wasser & Essen verkaufen – eine Taste pro Schritt",
    create = function(p) UI:Create(p) end,
    onShow = function() UI:Refresh() end,
})
