-- CBAS - Flipper: Reiter-Oberflaeche
-- Ablauf in 3 Schritten: 1. Kaufen  ->  2. Lager & Verkaufen (Einstellen)
-- Daneben: Merkliste (eigene Gegenstaende) und Haendler-Flips.
local ADDON, ns = ...
local F = ns.Flip
local FUI = {}
F.UI = FUI

local ROWS, ROW_H = 15, 20
local VIEWS = {
    kaufen = {
        title = "1 · Kaufen", w = 110, sort = "value",
        cols = {
            { key = "name",   label = "Gegenstand",   w = 196, align = "LEFT" },
            { key = "mode",   label = "Modus",        w = 46 },
            { key = "now",    label = "AH jetzt",     w = 76 },
            { key = "buy",    label = "Kauf bis",     w = 76 },
            { key = "sell",   label = "Verkauf für",  w = 76 },
            { key = "profit", label = "Gewinn/Stück", w = 82 },
            { key = "max",    label = "Max",          w = 40 },
            { key = "conf",   label = "Sicherheit",   w = 66 },
            { key = "value",  label = "Status",       w = 90 },
        },
    },
    lager = {
        title = "2 · Lager & Verkaufen", w = 170, sort = "status",
        cols = {
            { key = "name",   label = "Gegenstand",   w = 196, align = "LEFT" },
            { key = "mode",   label = "Modus",        w = 46 },
            { key = "bags",   label = "Taschen",      w = 54 },
            { key = "posted", label = "Im AH",        w = 50 },
            { key = "cost",   label = "Ø Einkauf",    w = 76 },
            { key = "sell",   label = "Verkauf für",  w = 76 },
            { key = "profit", label = "Gewinn/Stück", w = 82 },
            { key = "age",    label = "Gekauft",      w = 62 },
            { key = "status", label = "Status",       w = 130 },
        },
    },
    watch = {
        title = "Merkliste", w = 90, sort = "ahp",
        cols = {
            { key = "name",   label = "Gegenstand",   w = 190, align = "LEFT" },
            { key = "ahmin",  label = "AH-Min",       w = 76 },
            { key = "market", label = "Markt",        w = 76 },
            { key = "vendor", label = "Händler",      w = 66 },
            { key = "age",    label = "Alter",        w = 44 },
            { key = "buy",    label = "Kauf bis",     w = 76 },
            { key = "ahp",    label = "AH-Flip",      w = 96 },
            { key = "vp",     label = "Händler-Flip", w = 86 },
        },
    },
    found = {
        title = "Händler-Flips", w = 110, sort = "vp",
        cols = {
            { key = "name",   label = "Gegenstand",    w = 230, align = "LEFT" },
            { key = "ahmin",  label = "AH-Preis",      w = 90 },
            { key = "vendor", label = "Händler zahlt", w = 90 },
            { key = "vp",     label = "Gewinn/Stück",  w = 100 },
            { key = "pct",    label = "Gewinn %",      w = 70 },
            { key = "age",    label = "Gefunden",      w = 70 },
            { key = "auto",   label = "Auto-Verkauf",  w = 90 },
        },
    },
}
local ORDER = { "kaufen", "lager", "watch", "found" }

local HELP = {
    kaufen = "|cffffd100So geht's:|r AH öffnen, immer wieder die |cffffd100AUTOPILOT-Taste|r drücken (Tastenbelegung > AddOns) " ..
        "oder den großen Knopf neben dem AH. Er kauft, was grün ist, und stellt Gekauftes gleich wieder ein - ein Schritt pro Druck.\n" ..
        "|cff66ccff2h|r = verkauft sich sicher in ca. 2 Std. (viel Umsatz, ruhiger Preis). |cffccccccLang|r = Rezepte/Ausrüstung, mehr Gewinn, 1-3 Tage. " ..
        "Oben \"2h\" wählen = nur Schnell-Flips.",
    lager = "|cffffd100So geht's:|r Alles, was du über den Flipper gekauft hast. |cff40ff40Einstellen!|r macht der Autopilot von selbst " ..
        "(1. Druck prüft den Preis, 2. Druck stellt ein). Preis = knapp unter dem billigsten Angebot, damit es zuerst verkauft wird - " ..
        "aber nie unter Einkauf + Gebühr. Gold holt der Knopf am Briefkasten ab.",
    watch = "|cffffd100Merkliste:|r eigene Gegenstände beobachten. Gegenstand ins grüne Feld ziehen oder Link einfügen. " ..
        "Optional eigener Kauf-/Verkaufspreis. |cff40ff40KAUFEN|r = AH-Preis unter deinem Ziel.",
    found = "|cffffd100Händler-Flips:|r im AH billiger als der Händler zahlt. Kaufen, zum Händler - CBAS verkauft sie dort automatisch " ..
        "(\"Auto-Verkauf: an\"). Graue Gegenstände sind nur hier sinnvoll.",
}

local function Btn(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end
local function Tip(w, text)
    w:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    w:HookScript("OnLeave", GameTooltip_Hide)
end
local function Edit(parent, w)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end
local function Label(parent, text)
    local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetText(text)
    return l
end

-- "12g 50s" / "1250" / "12.5" -> Kupfer
local function ParseMoney(t)
    t = (t or ""):lower():gsub("%s", "")
    if t == "" then return nil end
    local g = tonumber(t:match("([%d%.]+)g")) or 0
    local s = tonumber(t:match("([%d%.]+)s")) or 0
    local k = tonumber(t:match("([%d%.]+)k")) or tonumber(t:match("([%d%.]+)c")) or 0
    if g == 0 and s == 0 and k == 0 then
        local n = tonumber(t)
        if not n then return nil end
        return math.floor(n * 10000 + 0.5)    -- reine Zahl = Gold
    end
    return math.floor(g * 10000 + s * 100 + k + 0.5)
end
FUI.ParseMoney = ParseMoney

local function PlainMoney(c)
    if not c or c <= 0 then return "" end
    local g, s = math.floor(c / 10000), math.floor(c / 100) % 100
    return (g > 0 and (g .. "g") or "") .. (s > 0 and (s .. "s") or "")
end

local function AgeText(days)
    if not days then return "|cff555555-|r" end
    if days == 0 then return "|cff40ff40heute|r" end
    if days <= 2 then return "|cffffd100" .. days .. "T|r" end
    return "|cffff4040" .. days .. "T|r"
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
function FUI:Create(p)
    self.frame = p
    self.view = "kaufen"
    self.offset = 0
    self.sortKey, self.sortDesc = VIEWS.kaufen.sort, true
    self.groups = { kaufen = {}, lager = {}, watch = {}, found = {} }
    local function Group(w, ...)
        for _, v in ipairs({ ... }) do table.insert(self.groups[v], w) end
        return w
    end

    -- Ansichten
    self.viewBtns = {}
    local x = 14
    for _, v in ipairs(ORDER) do
        local b = Btn(p, VIEWS[v].title, VIEWS[v].w)
        b:SetPoint("TOPLEFT", x, -30)
        b:SetScript("OnClick", function() FUI:SetView(v) end)
        self.viewBtns[v] = b
        x = x + VIEWS[v].w + 4
    end
    local hist = Btn(p, "Verlauf", 74)
    hist:SetPoint("TOPLEFT", x + 6, -30)
    hist:SetScript("OnClick", function()
        if FUI.selected then F.Chart.Show(FUI.selected) else F.Chart.ShowProfit() end
    end)
    Tip(hist, "Preisverlauf, Trends, Prognose des gewählten Gegenstands (auch: Rechtsklick auf eine Zeile).\nOhne Auswahl: dein Flip-Gewinn.")
    x = x + 84

    -- Modus-Filter (nur Kaufen)
    local modes = { { "alle", "Alle", 46 }, { "2h", "2h", 40 }, { "lang", "Lang", 50 } }
    self.modeBtns = {}
    local mx = x + 10
    for _, m in ipairs(modes) do
        local b = Group(Btn(p, m[2], m[3]), "kaufen")
        b:SetPoint("TOPLEFT", mx, -30)
        b:SetScript("OnClick", function()
            F.db().settings.flipMode = m[1]
            if F.Auto then F.Auto.queue = nil end
            if F.Snipe then F.Snipe.list = nil end
            FUI:Build(true)
        end)
        self.modeBtns[m[1]] = b
        mx = mx + m[3] + 2
    end
    Tip(self.modeBtns["2h"], "Nur Schnell-Flips: Handelsware mit viel Umsatz.\nKaufen, nach ein paar Stunden einstellen, verkauft sich meist am selben Tag.\nGilt auch für die Flip-Taste und den Sniper.")
    Tip(self.modeBtns["lang"], "Nur Lang-Flips: Rezepte, Bücher, Ausrüstung.\nMehr Gewinn pro Stück, verkauft sich aber erst in 1-3 Tagen.")
    local cb = Group(CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate"), "kaufen")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", mx + 6, -30)
    local cbt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbt:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    cbt:SetText("nur kaufbar")
    cb:SetScript("OnClick", function(c) F.db().settings.onlyBuyable = c:GetChecked() and true or false; FUI.offset = 0; FUI:Build(true) end)
    self.onlyBuyable = cb

    self.headerArea = CreateFrame("Frame", nil, p)
    self.headerArea:SetPoint("TOPLEFT", 14, -60)
    self.headerArea:SetSize(830, 20)
    self.area = CreateFrame("Frame", nil, p)
    self.area:SetPoint("TOPLEFT", 14, -80)
    self.area:SetSize(830, ROWS * ROW_H)
    self.area:EnableMouseWheel(true)
    self.area:SetScript("OnMouseWheel", function(_, d)
        FUI.offset = math.max(0, math.min(math.max(0, #FUI.list - ROWS), FUI.offset - d * 3))
        FUI:UpdateRows()
    end)

    -- Unterer Bereich: Einstellungen je Ansicht
    local Y1, Y2 = -390, -414
    -- Kaufen + Lager
    local l1 = Group(Label(p, "Min. Gewinn %:"), "kaufen")
    l1:SetPoint("TOPLEFT", 16, Y1)
    self.minPct = Group(Edit(p, 36), "kaufen")
    self.minPct:SetPoint("LEFT", l1, "RIGHT", 6, 0)
    self.minPct:SetScript("OnTextChanged", function(e, user)
        local n = tonumber(e:GetText())
        if user and n then F.db().settings.minProfitPct = n end
    end)
    Tip(self.minPct, "Mindestgewinn nach 5 % AH-Gebühr für eigene Analysen und die Merkliste (Claude-Tipps rechnen mit 15 %).")
    local l2 = Group(Label(p, "Budget pro Gegenstand (Gold):"), "kaufen")
    l2:SetPoint("LEFT", self.minPct, "RIGHT", 18, 0)
    self.budget = Group(Edit(p, 50), "kaufen")
    self.budget:SetPoint("LEFT", l2, "RIGHT", 6, 0)
    self.budget:SetScript("OnTextChanged", function(e, user)
        local n = tonumber(e:GetText())
        if user and n then F.db().settings.maxSpend = math.floor(n * 10000) end
    end)
    Tip(self.budget, "Höchstens so viel Gold pro Gegenstand ausgeben. 0 = kein Limit.")
    local l3 = Group(Label(p, "Einstellen frühestens nach (Std.):"), "kaufen", "lager")
    l3:SetPoint("TOPLEFT", 470, Y1)
    self.hours = Group(Edit(p, 30), "kaufen", "lager")
    self.hours:SetPoint("LEFT", l3, "RIGHT", 6, 0)
    self.hours:SetScript("OnTextChanged", function(e, user)
        local n = tonumber(e:GetText())
        if user and n and n >= 0 then F.db().settings.sellAfterH = n; FUI:Build(true) end
    end)
    Tip(self.hours, "0 = sofort wieder einstellen (empfohlen für 2h-Ware).\nMehr = erst nach so vielen Stunden, z.B. wenn du zur Raid-Zeit teurer verkaufen willst. CBAS erinnert dich dann (Ton + Chat).")
    local cj = Group(CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate"), "kaufen")
    cj:SetSize(22, 22)
    cj:SetPoint("LEFT", self.hours, "RIGHT", 14, 0)
    local cjt = cj:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cjt:SetPoint("LEFT", cj, "RIGHT", 0, 1)
    cjt:SetText("Quatsch ausblenden")
    cj:SetScript("OnClick", function(c) F.db().settings.hideJunk = c:GetChecked() and true or false; FUI:Build(true) end)
    Tip(cj, "Blendet graue Gegenstände, weiße Ausrüstung/Waffen (Hemden, Händlerwaffen) und beim Aufheben gebundene Sachen aus.\nEinzelne Gegenstände: auswählen + \"Ausblenden\".")
    self.hideJunk = cj

    -- Merkliste: Ablage, Link, eigene Preise
    local drop = Group(CreateFrame("Button", nil, p, "BackdropTemplate"), "watch")
    drop:SetSize(210, 44)
    drop:SetPoint("TOPLEFT", 14, Y1 + 2)
    if drop.SetBackdrop then
        drop:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        drop:SetBackdropColor(0.1, 0.3, 0.1, 0.5)
    end
    local dt = drop:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dt:SetAllPoints()
    dt:SetText("Gegenstand hierher ziehen\n(oder Shift-Klick ins Feld rechts)")
    local function TakeCursor()
        local kind, id, link = GetCursorInfo()
        if kind == "item" then
            F.Add(link or id)
            ClearCursor()
        end
    end
    drop:SetScript("OnReceiveDrag", TakeCursor)
    drop:SetScript("OnClick", TakeCursor)
    local addEdit = Group(Edit(p, 200), "watch")
    addEdit:SetPoint("LEFT", drop, "RIGHT", 14, 6)
    addEdit:SetScript("OnEnterPressed", function(e)
        local t = e:GetText()
        if t and t:find("|Hitem:", 1, true) then F.Add(t) end
        e:SetText("")
        e:ClearFocus()
    end)
    Tip(addEdit, "Hier klicken, dann einen Gegenstand mit Shift-Klick verlinken und Enter drücken.")
    local al = Group(p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"), "watch")
    al:SetPoint("TOPLEFT", addEdit, "BOTTOMLEFT", -4, -2)
    al:SetText("Link einfügen + Enter")
    local bl = Group(Label(p, "Eigener Kaufpreis:"), "watch")
    bl:SetPoint("TOPLEFT", 470, Y1)
    self.buyEdit = Group(Edit(p, 80), "watch")
    self.buyEdit:SetPoint("LEFT", bl, "RIGHT", 8, 0)
    local sl = Group(Label(p, "Eigener Verkaufspreis:"), "watch")
    sl:SetPoint("TOPLEFT", 470, Y2)
    self.sellEdit = Group(Edit(p, 80), "watch")
    self.sellEdit:SetPoint("LEFT", sl, "RIGHT", 8, 0)
    for _, pair in ipairs({ { self.buyEdit, "buyAt" }, { self.sellEdit, "sellAt" } }) do
        local e, field = pair[1], pair[2]
        e:SetScript("OnTextChanged", function(ed, user)
            if not user or not FUI.selected then return end
            local w = F.db().watch[FUI.selected]
            if w then w[field] = ParseMoney(ed:GetText()); FUI:Build(true) end
        end)
        Tip(e, "Leer = automatisch aus Markt und Mindestgewinn.\nEingabe z.B. 12g50s oder 12.5 (= Gold).")
    end
    -- Haendler-Flips
    local vl = Group(Label(p, "Min. Händler-Gewinn:"), "found")
    vl:SetPoint("TOPLEFT", 16, Y1)
    self.minVendor = Group(Edit(p, 50), "found")
    self.minVendor:SetPoint("LEFT", vl, "RIGHT", 6, 0)
    self.minVendor:SetScript("OnTextChanged", function(e, user)
        local c = ParseMoney(e:GetText())
        if user and c then F.db().settings.minVendorProfit = c end
    end)
    Tip(self.minVendor, "Gewinn pro Stück, z.B. 50s oder 0.5 (= Gold)")

    local det = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    det:SetPoint("TOPLEFT", 16, -440)
    det:SetPoint("TOPRIGHT", -16, -440)
    det:SetJustifyH("LEFT")
    det:SetJustifyV("TOP")
    det:SetSpacing(2)
    self.det = det
    local src = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    src:SetPoint("BOTTOMRIGHT", -18, 40)
    src:SetJustifyH("RIGHT")
    self.src = src

    -- Knoepfe je Ansicht (werden in SetView angeordnet)
    local B = {}
    B.search = Btn(p, "Im AH suchen", 120)
    B.search:SetScript("OnClick", function() FUI:SearchSelected() end)
    Tip(B.search, "Sucht den gewählten Gegenstand im offenen Auktionshaus.\nOhne Auswahl: alle kaufbaren der Liste (über Auctionator).")
    B.analyze = Btn(p, "Jetzt analysieren", 130)
    B.analyze:SetScript("OnClick", function() F.Analyze(); FUI:Build() end)
    Tip(B.analyze, "Geht deine Auctionator-Scans durch und sucht neue Vorschläge (zusätzlich zu den Claude-Tipps).\nPassiert auch automatisch nach jedem AH-Besuch.")
    B.toWatch = Btn(p, "Auf Merkliste", 110)
    B.toWatch:SetScript("OnClick", function() if FUI.selected then F.Add(FUI.selected) end end)
    B.ignore = Btn(p, "Ausblenden", 100)
    B.ignore:SetScript("OnClick", function()
        if not FUI.selected then return end
        F.Ignore(FUI.selected, true)
        local i = F.ItemInfo(FUI.selected)
        ns.Print("Flipper: " .. ((i and i.link) or FUI.selected) .. " ausgeblendet. Zurückholen: /crap flip ignore reset")
        if F.Auto then F.Auto.queue = nil end
        FUI.selected = nil
        FUI:Build(true)
    end)
    Tip(B.ignore, "Diesen Gegenstand nie mehr vorschlagen (auch nicht für Flip-Taste und Sniper).")
    B.post = Btn(p, "Einstellen (im AH)", 140)
    B.post:SetScript("OnClick", function() F.Stock.Step() end)
    Tip(B.post, "Wie der Knopf im Kaufhilfe-Fenster: 1. Klick prüft den Marktpreis, 2. Klick stellt ein.\nNur mit offenem Auktionshaus.")
    B.unstock = Btn(p, "Aus Lager entfernen", 140)
    B.unstock:SetScript("OnClick", function()
        if FUI.selected then F.Stock.db()[FUI.selected] = nil; FUI.selected = nil; FUI:Build(true) end
    end)
    Tip(B.unstock, "Z.B. wenn du den Gegenstand selbst benutzt oder anders verkauft hast.")
    B.deals = Btn(p, "Alle Schnäppchen suchen", 170)
    B.deals:SetScript("OnClick", function() FUI:SearchDeals() end)
    B.vend = Btn(p, "Händler-Verkauf", 130)
    B.vend:SetScript("OnClick", function()
        if FUI.selected then F.MarkVendor(FUI.selected, not F.IsVendorMarked(FUI.selected)) end
    end)
    Tip(B.vend, "An = wird beim nächsten Händler automatisch aus deinen Taschen verkauft.\nNur für Gegenstände, die du nicht selbst brauchst!")
    B.del = Btn(p, "Entfernen", 90)
    B.del:SetScript("OnClick", function()
        if not FUI.selected then return end
        if FUI.view == "watch" then F.Remove(FUI.selected)
        elseif FUI.view == "found" then F.db().found[FUI.selected] = nil end
        FUI.selected = nil
        FUI:Build()
    end)
    self.B = B
    self.btnLayout = {
        kaufen = { "search", "analyze", "toWatch", "ignore" },
        lager = { "post", "unstock" },
        watch = { "search", "deals", "del" },
        found = { "search", "deals", "vend", "del" },
    }

    p:SetScript("OnShow", function() FUI:Build() end)
    p:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    p:RegisterEvent("AUCTION_HOUSE_CLOSED")
    p:RegisterEvent("BAG_UPDATE_DELAYED")
    p:SetScript("OnEvent", function()
        if p:IsVisible() and not FUI.queued then
            FUI.queued = true
            C_Timer.After(1.5, function() FUI.queued = false; FUI:Build(true) end)
        end
    end)
    F.Refresh = function() if p:IsVisible() then FUI:Build(true) end end
    self:SetView("kaufen", true)
end

function FUI:SetView(v, noBuild)
    self.view = v
    self.offset = 0
    self.sortKey, self.sortDesc = VIEWS[v].sort, true
    self.selected = nil
    for gv, list in pairs(self.groups) do
        if gv ~= v then for _, w in ipairs(list) do w:Hide() end end
    end
    for _, w in ipairs(self.groups[v]) do w:Show() end
    for _, b in pairs(self.B) do b:Hide() end
    local prev
    for _, k in ipairs(self.btnLayout[v]) do
        local b = self.B[k]
        b:ClearAllPoints()
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("BOTTOMLEFT", 14, 12) end
        b:Show()
        prev = b
    end
    if not noBuild then self:Build() end
end

function FUI:MakeColumns()
    local cols = VIEWS[self.view].cols
    if self.builtView == self.view then return cols end
    self.builtView = self.view
    for _, h in ipairs(self.headers or {}) do h:Hide() end
    for _, r in ipairs(self.rows or {}) do r:Hide() end
    self.headers, self.rows = {}, {}
    local x = 0
    for _, c in ipairs(cols) do
        local h = CreateFrame("Button", nil, self.headerArea)
        h:SetSize(c.w, 18)
        h:SetPoint("TOPLEFT", x, 0)
        local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetJustifyH(c.align or "CENTER")
        h.fs, h.col = fs, c
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        h:SetScript("OnClick", function()
            if FUI.sortKey == c.key then FUI.sortDesc = not FUI.sortDesc
            else FUI.sortKey, FUI.sortDesc = c.key, c.key ~= "name" end
            FUI:Build(true)
        end)
        self.headers[#self.headers + 1] = h
        x = x + c.w + 2
    end
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, self.area)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetSize(x, ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local deal = r:CreateTexture(nil, "BACKGROUND")
        deal:SetAllPoints()
        deal:SetColorTexture(0.1, 0.8, 0.1, 0.22)
        deal:Hide()
        r.deal = deal
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.2, 0.6, 1, 0.3)
        sel:Hide()
        r.sel = sel
        r.cells = {}
        local cx = 0
        for ci, c in ipairs(cols) do
            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 2, 0)
            fs:SetSize(c.w - 4, ROW_H)
            fs:SetJustifyH(c.align or "CENTER")
            fs:SetWordWrap(false)
            r.cells[ci] = fs
            cx = cx + c.w + 2
        end
        r:SetScript("OnEnter", function(row)
            if row.link then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetHyperlink, GameTooltip, row.link)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        r:SetScript("OnClick", function(row, button)
            if button == "RightButton" and row.id then
                FUI.selected = row.id; FUI:Build(true)
                F.Chart.Show(row.id)
                return
            end
            if IsModifiedClick and IsModifiedClick("CHATLINK") and row.link and ChatEdit_InsertLink then
                ChatEdit_InsertLink(row.link)
                return
            end
            if row.id then FUI.selected = row.id; FUI:Build(true) end
        end)
        self.rows[i] = r
    end
    return cols
end

---------------------------------------------------------------------------
-- Listen
---------------------------------------------------------------------------
-- eine Kauf-Liste aus Claude-Tipps und eigenen Vorschlaegen
function FUI:KaufList()
    local d = F.db()
    local mode = d.settings.flipMode or "alle"
    local only = d.settings.onlyBuyable
    local list, seen = {}, {}
    local function add(id, x)
        if seen[id] or F.IsJunk(id) then return end
        seen[id] = true
        local info = F.ItemInfo(id)
        local p = F.Prices(info and info.link or id)
        x.id, x.info = id, info
        x.name = info and info.name or ("Gegenstand " .. id)
        x.link = info and info.link
        x.mode = F.IsQuick(id) and "2h" or "lang"
        if mode ~= "alle" and x.mode ~= mode then return end
        x.now = p.ahMin
        x.buyable = x.now and x.buyUpTo and x.now <= x.buyUpTo
        if only and not x.buyable then return end
        local net = (x.sellAt or 0) * (1 - F.AH_CUT)
        x.profit = net - (x.buyable and x.now or x.buyUpTo or net)
        x.value = (x.buyable and 1e12 or 0) + x.profit * (x.maxQty or 3) * (x.conf or 0.5)
        list[#list + 1] = x
    end
    local c, fresh = F.Claude()
    if c and fresh and type(c.items) == "table" then
        for id, t in pairs(c.items) do
            add(id, { buyUpTo = t.buyUpTo, sellAt = t.sellAt, maxQty = t.maxQty, conf = t.conf, reason = t.reason, src = "Claude", rank = t.rank })
        end
    end
    for id, e in pairs(d.suggest or {}) do
        if not e.odd then
            local T = F.Targets(e.link or id, id)
            add(id, { buyUpTo = T.ahMax, sellAt = e.avg, conf = math.max(0, 1 - (e.cv or 0.5)), src = "Analyse",
                reason = string.format("Eigene Analyse: Median %s, in %d von 14 Tagen im AH, Schwankung %.0f %%.", F.Money(e.avg, true), e.days or 0, (e.cv or 0) * 100) })
        end
    end
    return list
end

function FUI:LagerList()
    F.Stock.Cleanup()
    local list = {}
    for id, e in pairs(F.Stock.db()) do
        local info = F.ItemInfo(id)
        local status, ready = F.Stock.Status(id, e)
        local uc = F.Stock.UnitCost(e)
        list[#list + 1] = { id = id, e = e, name = info and info.name or ("Gegenstand " .. id), link = info and info.link,
            bags = F.Stock.BagCount(id), status = status, ready = ready, cost = uc,
            profit = (e.target or 0) * (1 - F.AH_CUT) - uc }
    end
    return list
end

function FUI:BuildList()
    local d = F.db()
    local v = self.view
    local list = {}
    if v == "kaufen" then
        list = self:KaufList()
    elseif v == "lager" then
        list = self:LagerList()
    elseif v == "watch" then
        for id, w in pairs(d.watch) do
            local p = F.Prices(w.link or id)
            local info = p.info
            if info and info.link then w.link = info.link end
            list[#list + 1] = { id = id, w = w, p = p, af = F.AHFlip(p, w), vf = F.VendorFlip(p),
                name = info and info.name or ("Gegenstand " .. id), link = w.link }
        end
    else
        for id, e in pairs(d.found) do
            local info = F.ItemInfo(e.link or id)
            list[#list + 1] = { id = id, e = e, name = info and info.name or ("Gegenstand " .. id), link = e.link,
                pct = e.ah > 0 and (e.profit / e.ah * 100) or 0 }
        end
    end
    local k, desc = self.sortKey, self.sortDesc
    local function val(x)
        if k == "name" then return x.name:lower() end
        if v == "kaufen" then
            if k == "mode" then return x.mode end
            if k == "now" then return x.now or 0 end
            if k == "buy" then return x.buyUpTo or 0 end
            if k == "sell" then return x.sellAt or 0 end
            if k == "profit" then return x.profit or 0 end
            if k == "max" then return x.maxQty or 0 end
            if k == "conf" then return x.conf or 0 end
            return x.value or 0
        elseif v == "lager" then
            local e = x.e
            if k == "mode" then return e.mode or "" end
            if k == "bags" then return x.bags end
            if k == "posted" then return e.posted or 0 end
            if k == "cost" then return x.cost end
            if k == "sell" then return e.target or 0 end
            if k == "profit" then return x.profit end
            if k == "age" then return e.lastBuy or 0 end
            return (x.ready and 1e12 or 0) + (e.lastBuy or 0)
        elseif v == "found" then
            local e = x.e
            if k == "auto" then return F.IsVendorMarked(x.id) and 1 or 0 end
            if k == "ahmin" then return e.ah end
            if k == "vendor" then return e.vendor end
            if k == "vp" then return e.profit end
            if k == "pct" then return x.pct end
            if k == "age" then return e.t or 0 end
            return 0
        end
        local p = x.p
        if k == "ahmin" then return p.ahMin or 0 end
        if k == "market" then return p.market or 0 end
        if k == "vendor" then return p.vendor or 0 end
        if k == "age" then return -(p.age or 999) end
        if k == "buy" then return x.af and x.af.buyUpTo or 0 end
        if k == "ahp" then return (x.af and x.af.deal and 1e9 or 0) + (x.af and x.af.pct or -1e6) end
        if k == "vp" then return x.vf and x.vf.profit or -1e9 end
        return 0
    end
    table.sort(list, function(a, b)
        local va, vb = val(a), val(b)
        if va == vb then return a.name < b.name end
        if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
        if desc then return va > vb end
        return va < vb
    end)
    self.list = list
end

---------------------------------------------------------------------------
-- Zeilen
---------------------------------------------------------------------------
local function Conf(c)
    c = c or 0
    return c >= 0.65 and "|cff40ff40hoch|r" or (c >= 0.45 and "|cffffd100mittel|r" or "|cffff4040niedrig|r")
end
local function ModeTxt(m) return m == "2h" and "|cff66ccff2h|r" or "|cffccccccLang|r" end

function FUI:UpdateRows()
    local M = F.Money
    local v = self.view
    for i = 1, ROWS do
        local r = self.rows[i]
        local x = self.list[self.offset + i]
        if x then
            r.id, r.link = x.id, x.link
            local c = r.cells
            r.deal:Hide()
            c[1]:SetText(x.link or x.name)
            if v == "kaufen" then
                c[2]:SetText(ModeTxt(x.mode))
                c[3]:SetText(x.now and M(x.now, true) or "|cff555555-|r")
                c[4]:SetText(M(x.buyUpTo, true))
                c[5]:SetText(M(x.sellAt, true))
                c[6]:SetText(x.profit and x.profit > 0 and ("|cff40ff40+" .. M(x.profit, true) .. "|r") or "|cff555555-|r")
                c[7]:SetText(x.maxQty and tostring(x.maxQty) or "-")
                c[8]:SetText(Conf(x.conf))
                c[9]:SetText(x.buyable and "|cff40ff40KAUFEN|r" or (x.now and "|cff888888zu teuer|r" or "|cff888888nicht im AH|r"))
                if x.buyable then r.deal:Show() end
            elseif v == "lager" then
                local e = x.e
                c[2]:SetText(ModeTxt(e.mode))
                c[3]:SetText(tostring(x.bags))
                c[4]:SetText(tostring(e.posted or 0))
                c[5]:SetText(M(x.cost, true))
                c[6]:SetText(M(e.target, true))
                c[7]:SetText(x.profit > 0 and ("|cff40ff40+" .. M(x.profit, true) .. "|r") or ("|cffff4040" .. M(-x.profit, true) .. "|r"))
                c[8]:SetText(ns.Ago(e.lastBuy or e.t))
                c[9]:SetText(x.status)
                if x.ready then r.deal:Show() end
            elseif v == "watch" then
                local p, af, vf = x.p, x.af, x.vf
                c[2]:SetText(M(p.ahMin, true))
                c[3]:SetText(M(p.market, true))
                c[4]:SetText(M(p.vendor, true))
                c[5]:SetText(AgeText(p.age))
                c[6]:SetText(af and M(af.buyUpTo, true) or "|cff555555-|r")
                if af and af.profit then
                    local col = af.deal and "|cff40ff40" or (af.profit > 0 and "|cffffd100" or "|cffff4040")
                    c[7]:SetText(string.format("%s%+.0f%%|r %s", col, af.pct, af.deal and "|cff40ff40KAUFEN|r" or ""))
                    if af.deal then r.deal:Show() end
                else
                    c[7]:SetText("|cff555555-|r")
                end
                if vf and vf.profit then
                    c[8]:SetText((vf.deal and "|cff40ff40+" or (vf.profit > 0 and "|cffffd100+" or "|cff888888")) ..
                        (vf.profit > 0 and M(vf.profit, true) or "nein") .. "|r")
                else
                    c[8]:SetText("|cff555555-|r")
                end
            else
                local e = x.e
                c[2]:SetText(M(e.ah, true))
                c[3]:SetText(M(e.vendor, true))
                c[4]:SetText("|cff40ff40+" .. M(e.profit, true) .. "|r")
                c[5]:SetText(string.format("%.0f%%", x.pct))
                c[6]:SetText(ns.Ago(e.t))
                c[7]:SetText(F.IsVendorMarked(x.id) and "|cff40ff40an|r" or "|cff888888aus|r")
            end
            if self.selected == x.id then r.sel:Show() else r.sel:Hide() end
            r:Show()
        else
            r.id, r.link = nil, nil
            r:Hide()
        end
    end
end

function FUI:UpdateDetail()
    local d = F.db()
    local M = F.Money
    local v = self.view
    local x
    for _, e in ipairs(self.list) do if e.id == self.selected then x = e end end
    local txt
    if x and v == "kaufen" then
        txt = string.format("%s %s · |cffffd100Kaufen bis|r %s · |cffffd100einstellen für|r %s%s · %s\n|cff66ccff%s:|r %s  |cff888888(Rechtsklick = Verlauf)|r",
            x.link or x.name, ModeTxt(x.mode), M(x.buyUpTo), M(x.sellAt), x.maxQty and (" · höchstens " .. x.maxQty .. " Stück") or "",
            x.mode == "2h" and "verkauft sich in ca. 2 Std." or "verkauft sich in 1-3 Tagen",
            x.src or "Info", x.reason or "-")
    elseif x and v == "lager" then
        local e = x.e
        txt = string.format("%s: %d gekauft für Ø %s · %d im AH · %d verkauft (%s) · nie unter %s einstellen.",
            x.link or x.name, e.qty, M(x.cost), e.posted or 0, e.sold or 0, M(e.revenue or 0), M(F.Stock.Floor(e)))
    elseif x and v == "watch" then
        local p, af, vf = x.p, x.af, x.vf
        local L = {}
        if af then
            L[#L + 1] = string.format("|cffffd100AH-Flip:|r kaufen bis %s, verkaufen für %s (nach 5%% Gebühr %s)%s |cff888888[%s]|r",
                M(af.buyUpTo), M(af.sell), M(af.net), af.profit and string.format(" · jetzt %+.0f%%", af.pct) or "", af.src or "?")
        else
            L[#L + 1] = "|cffffd100AH-Flip:|r |cff888888noch kein Marktwert (mind. 3 Scan-Tage) - trag einen eigenen Verkaufspreis ein.|r"
        end
        if vf then
            L[#L + 1] = string.format("|cffffd100Händler-Flip:|r kaufen bis %s, Händler zahlt %s", M(vf.buyUpTo), M(vf.vendor))
        end
        txt = table.concat(L, "\n")
    end
    if not txt then
        if F.scanning then
            txt = string.format("|cffffd100Analysiere ... %d/%d|r", F.scanning.i, F.scanning.n)
        else
            txt = HELP[v]
        end
    end
    self.det:SetText(txt)
    -- Felder
    local w = v == "watch" and self.selected and d.watch[self.selected]
    self.buyEdit:SetEnabled(w and true or false)
    self.sellEdit:SetEnabled(w and true or false)
    if not self.buyEdit:HasFocus() then self.buyEdit:SetText(w and PlainMoney(w.buyAt) or "") end
    if not self.sellEdit:HasFocus() then self.sellEdit:SetText(w and PlainMoney(w.sellAt) or "") end
    if not self.minPct:HasFocus() then self.minPct:SetText(tostring(d.settings.minProfitPct)) end
    if not self.budget:HasFocus() then self.budget:SetText(tostring(math.floor((d.settings.maxSpend or 0) / 10000))) end
    if not self.hours:HasFocus() then self.hours:SetText(tostring(F.Stock.Hours())) end
    if not self.minVendor:HasFocus() then self.minVendor:SetText(PlainMoney(d.settings.minVendorProfit) ~= "" and PlainMoney(d.settings.minVendorProfit) or (d.settings.minVendorProfit .. "k")) end
    self.hideJunk:SetChecked(d.settings.hideJunk ~= false)
    self.onlyBuyable:SetChecked(d.settings.onlyBuyable and true or false)
    local B = self.B
    B.toWatch:SetEnabled(self.selected ~= nil)
    B.ignore:SetEnabled(self.selected ~= nil)
    B.unstock:SetEnabled(self.selected ~= nil)
    B.del:SetEnabled(self.selected ~= nil)
    B.vend:SetEnabled(self.selected ~= nil)
    B.vend:SetText(self.selected and F.IsVendorMarked(self.selected) and "Händler-Verkauf: an" or "Händler-Verkauf")
    B.post:SetText(F.Stock.ButtonText())
end

function FUI:Build(keepCols)
    if not self.frame or not self.frame:IsVisible() then return end
    self:MakeColumns()
    for v, b in pairs(self.viewBtns) do
        if v == self.view then b:LockHighlight() else b:UnlockHighlight() end
    end
    local mode = F.db().settings.flipMode or "alle"
    for m, b in pairs(self.modeBtns) do
        if m == mode then b:LockHighlight() else b:UnlockHighlight() end
    end
    for _, h in ipairs(self.headers) do
        local arrow = (h.col.key == self.sortKey) and (self.sortDesc and " v" or " ^") or ""
        h.fs:SetText(h.col.label .. arrow)
        h:Show()
    end
    self:BuildList()
    self.offset = math.min(self.offset, math.max(0, #self.list - ROWS))
    self:UpdateRows()
    self:UpdateDetail()
    local s = {}
    s[#s + 1] = F.HasAuctionator() and "|cff40ff40Auctionator|r" or "|cff888888Auctionator fehlt|r"
    s[#s + 1] = F.HasTSM() and "|cff40ff40TSM|r" or "|cff888888TSM fehlt|r"
    local c, fresh = F.Claude()
    if c then s[#s + 1] = fresh and ("Claude-Tipps vom " .. date("%d.%m. %H:%M", c.generated)) or "|cffff4040Claude-Tipps veraltet|r" end
    if self.view == "kaufen" then
        local n = 0
        for _, x in ipairs(self.list) do if x.buyable then n = n + 1 end end
        s[#s + 1] = #self.list .. " Einträge · |cff40ff40" .. n .. " jetzt kaufbar|r"
    elseif self.view == "lager" then
        local n = 0
        for _, x in ipairs(self.list) do if x.ready then n = n + 1 end end
        s[#s + 1] = #self.list .. " im Lager · |cff40ff40" .. n .. " bereit zum Einstellen|r"
    else
        s[#s + 1] = #self.list .. " Einträge"
    end
    self.src:SetText(table.concat(s, " · "))
    -- Reiter-Knopf "Lager" mit Zahl
    local ready = #F.Stock.ReadyList()
    self.viewBtns.lager:SetText(ready > 0 and ("2 · Lager (|cff40ff40" .. ready .. "|r)") or VIEWS.lager.title)
end

function FUI:SearchSelected()
    local x
    for _, e in ipairs(self.list or {}) do if e.id == self.selected then x = e end end
    if not x then self:SearchDeals() return end
    F.SearchAH(x.name)
end

function FUI:SearchDeals()
    local names = {}
    for _, x in ipairs(self.list or {}) do
        local deal = (self.view == "kaufen" and x.buyable) or self.view == "found" or (x.af and x.af.deal) or (x.vf and x.vf.deal)
        if deal and x.name and not x.name:find("^Gegenstand ") then names[#names + 1] = x.name end
        if #names >= 50 then break end
    end
    if #names == 0 then ns.Print("Flipper: gerade keine Schnäppchen in der Liste.") return end
    if not (F.HasAuctionator() and Auctionator.API.v1.MultiSearchExact) then
        ns.Print("Flipper: mehrere Gegenstände auf einmal suchen geht nur mit Auctionator - suche den ersten.")
    end
    F.SearchAH(names)
end

ns.Suite:RegisterModule({
    id = "flipper",
    name = "Flipper",
    create = function(p) FUI:Create(p) end,
    onShow = function() FUI:Build() end,
})
