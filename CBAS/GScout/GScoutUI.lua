-- CBAS (Craphunts Blacklisted Addon Suite) - Oberflaeche
local ADDON, ns = ...
local UI = {}
ns.UI = UI

local ROWS, ROW_H = 18, 20
local COLS = {
    { key = "name",    label = "Gilde",    w = 112, align = "LEFT" },
    { key = "faction", label = "Fr.",      w = 18 },
    { key = "lang",    label = "Spr.",     w = 30 },
    { key = "members", label = "Größe",    w = 44 },
    { key = "max",     label = "60er",     w = 30 },
    { key = "score",   label = "Leistung", w = 44 },
    { key = "recruit", label = "Rekrut.",  w = 46 },
    { key = "wanted",  label = "Sucht",    w = 62, align = "LEFT" },
    { key = "loot",    label = "Loot",     w = 56, align = "LEFT" },
    { key = "rating",  label = "Wert.",    w = 30 },
}

UI.sortKey = "recruit"
UI.sortDesc = true
UI.offset = 0
UI.list = {}

local function ClassColor(file)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c and c.colorStr then return "|c" .. c.colorStr end
    return "|cffffffff"
end

-- gesuchte Klassen als kleine Symbole (eigene Klasse zuerst); alte Angaben (> 30 Tage) grau
local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local ROLE_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local CLASS_COORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, SHAMAN = { 0.25, 0.49609375, 0.25, 0.5 },
    PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 }, WARLOCK = { 0.7421875, 0.98828125, 0.25, 0.5 }, PALADIN = { 0, 0.25, 0.5, 0.75 },
}
local ROLE_COORDS = { TANK = { 0, 19, 22, 41 }, HEAL = { 20, 39, 1, 20 }, DPS = { 20, 39, 22, 41 } }
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "TANK", "HEAL", "DPS" }

local function Icon(w, stale)
    local col = stale and ":110:110:110" or ""
    local c = (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[w]) or CLASS_COORDS[w]
    if c then
        return string.format("|T%s:13:13:0:0:256:256:%d:%d:%d:%d%s|t", CLASS_TEX,
            math.floor(c[1] * 256), math.floor(c[2] * 256), math.floor(c[3] * 256), math.floor(c[4] * 256), col)
    end
    local r = ROLE_COORDS[w]
    if r then return string.format("|T%s:13:13:0:0:64:64:%d:%d:%d:%d%s|t", ROLE_TEX, r[1], r[2], r[3], r[4], col) end
    return ""
end

function UI.WantedIcons(g, max)
    if not g.wanted or not next(g.wanted) then return nil end
    local stale = (g.wantedTime or 0) < time() - 30 * 86400
    local _, my = UnitClass("player")
    local list = {}
    if my and g.wanted[my] then list[1] = my end
    for _, w in ipairs(CLASS_ORDER) do if g.wanted[w] and w ~= my then list[#list + 1] = w end end
    max = max or 4
    local out = {}
    for i = 1, math.min(#list, max) do out[i] = Icon(list[i], stale) end
    local txt = table.concat(out, "")
    if #list > max then txt = txt .. "|cff888888+" .. (#list - max) .. "|r" end
    return txt, list, stale
end

local function ClassName(file)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file
end

local ROLE_NAMES = { TANK = "Tank", HEAL = "Heiler", DPS = "DD" }

local function FactionTag(f)
    if f == "Alliance" then return "|cff4a9effA|r" end
    if f == "Horde" then return "|cffff4040H|r" end
    return "|cff888888?|r"
end

local function Date(t)
    return t and date("%d.%m.%y %H:%M", t) or "-"
end

---------------------------------------------------------------------------
-- Daten fuer die Liste
---------------------------------------------------------------------------
local function SortValue(e, key)
    local g = e.g
    if key == "name" then return g.name:lower() end
    if key == "faction" then return g.faction or "" end
    if key == "members" then return math.max(g.memberCount, (g.inspect and g.inspect.members) or 0) end
    if key == "lang" then return ns.LangTag(g) end
    if key == "max" then return e.atMax end
    if key == "score" then return e.score or 0 end
    if key == "recruit" then return g.recruit.last or 0 end
    if key == "loot" then return ns.LootString(g):lower() end
    if key == "wanted" then
        -- sucht meine Klasse (frisch) zuerst, dann nach Aktualitaet
        if not g.wanted or not next(g.wanted) then return 0 end
        local _, my = UnitClass("player")
        local fresh = (g.wantedTime or 0) >= time() - 30 * 86400
        return ((my and g.wanted[my] and fresh) and 1e10 or 0) + (g.wantedTime or 0)
    end
    if key == "inst" then
        local f = UI.instFilter
        local ie = f and g.instances and g.instances[f]
        if not ie then return 0 end
        return ((ie.groups or 0) * 100 + (ie.max or 0)) * 1e10 + math.max(ie.seen or 0, ie.mention or 0)
    end
    if key == "rating" then
        return (g.blacklist and -10 or 0) + (g.favorite and 10 or 0) + (g.rating or 0)
    end
    return 0
end

function UI:Sel()
    local k = self.selected
    if not k then return nil end
    return ns.db.guilds[k] or (self.pseudo and self.pseudo[k])
end

-- Rekrutierer ohne erkannten Gildennamen als Platzhalter-Eintrag
local function MakePseudo(full, plist)
    local short, realm = ns.SplitName(full)
    local g = {
        name = "? über " .. short, realm = realm, pseudo = full,
        members = {}, memberCount = 0, maxRankIndex = 0, ranks = {},
        loot = {}, tags = {}, wanted = {}, notes = "", rating = 0,
        firstSeen = plist[#plist].t, lastSeen = plist[1].t,
        recruit = {
            msgs = plist, count = #plist, posts = #plist, last = plist[1].t, lastFrom = full,
            recruiters = { [full] = { t = plist[1].t, class = plist[1].class, race = plist[1].race } },
        },
    }
    g.faction = ns.FactionOfRace(plist[1].race)
    for i = #plist, 1, -1 do ns.ParseDetails(g, plist[i].text) end
    return g
end

-- Zeilenwerte je Gilde zwischenspeichern (Max-Level-Zahl, Leistung) - spart beim
-- Neuaufbau der Liste fast die ganze Rechenzeit. Schwache Schluessel = kein Speicherleck.
local rowCache = setmetatable({}, { __mode = "k" })
local function RowValues(g)
    local c = rowCache[g]
    local now = GetTime()
    if c and now - c.t < 15 then return c end
    c = c or {}
    c.t = now
    c.atMax = ns.Stats(g)
    if ns.ScoreText and not g.pseudo then c.scoreText, c.score = ns.ScoreText(g) else c.scoreText, c.score = nil, 0 end
    rowCache[g] = c
    return c
end

function UI:BuildList()
    local list = {}
    local all = {}
    for key, g in pairs(ns.db.guilds) do all[key] = g end
    self.pseudo = {}
    for full, plist in pairs(ns.db.pending) do
        if plist[1] then
            local key = "pending:" .. full
            local pg = MakePseudo(full, plist)
            self.pseudo[key] = pg
            all[key] = pg
        end
    end
    local search = self.search and self.search:GetText():lower() or ""
    local onlyRecruit = self.cbRecruit and self.cbRecruit:GetChecked()
    local onlyFaction = self.cbFaction and self.cbFaction:GetChecked()
    local hideBL = self.cbBlacklist and self.cbBlacklist:GetChecked()
    local myFaction = UnitFactionGroup("player")
    local nRecruit = 0
    for key, g in pairs(all) do
        local recruiting = ns.IsRecruiting(g)
        if recruiting then nRecruit = nRecruit + 1 end
        local ok = true
        if onlyRecruit and not recruiting then ok = false end
        if ok and onlyFaction and g.faction and g.faction ~= myFaction then ok = false end
        if ok and self.instFilter and not ns.HasInstance(g, self.instFilter) then ok = false end
        if ok and hideBL and g.blacklist then ok = false end
        if ok and search ~= "" then
            local hay = (g.name .. " " .. (g.notes or "") .. " " .. ns.LootString(g) .. " " .. (g.days or "")):lower()
            for t in pairs(g.tags) do hay = hay .. " " .. t:lower() end
            for k in pairs(g.instances or {}) do hay = hay .. " " .. k:lower() .. " " .. ns.InstanceName(k):lower() end
            hay = hay .. " " .. ns.LangTag(g):lower() .. " " .. (ns.LANG_NAMES[g.lang or ""] or ""):lower()
            if not hay:find(search, 1, true) then ok = false end
        end
        local rv = ok and RowValues(g)
        if ok and self.cbTop and self.cbTop:GetChecked() and (rv.score or 0) < 50 then ok = false end
        if ok then
            list[#list + 1] = { key = key, g = g, atMax = rv.atMax, score = rv.score or 0, scoreText = rv.scoreText }
        end
    end
    local sk, desc = self.sortKey, self.sortDesc
    -- Sortierwert einmal je Eintrag berechnen (nicht bei jedem Vergleich)
    for _, e in ipairs(list) do e.sv = SortValue(e, sk); e.ln = e.g.name:lower() end
    table.sort(list, function(a, b)
        local va, vb = a.sv, b.sv
        if va == vb then return a.ln < b.ln end
        if desc then return va > vb end
        return va < vb
    end)
    self.list = list
    self.totalRecruit = nRecruit
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------
local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    return b
end

local function MakeCheck(parent, label, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = (type(cb.Text) == "table" and cb.Text) or (type(cb.text) == "table" and cb.text) or nil
    if not fs then
        fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    fs:SetFontObject("GameFontHighlightSmall")
    fs:SetText(label)
    cb.label = fs
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", GameTooltip_Hide)
    end
    return cb
end

local function Backdrop(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.5)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
end

local function Tip(widget, text)
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(text, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", GameTooltip_Hide)
end

-- Baut den GScout-Reiter in den Inhaltsbereich der Suite (parent)
function UI:Create(parent)
    if self.frame then return end
    if not parent then
        ns.Suite:Create()   -- erzeugt die Suite und ruft uns mit dem Reiter-Bereich auf
        return
    end
    local f = parent
    self.frame = f
    f:SetScript("OnShow", function() UI:Refresh() end)
    -- Countdown der /who-Sperre live in den Knoepfen anzeigen
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.1 then return end
        acc = 0
        if UI.cdActive or ns.WhoCooldown() > 0 then UI:UpdateCooldowns() end
    end)

    -- Suche & Filter
    local sl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sl:SetPoint("TOPLEFT", 16, -36)
    sl:SetText("Suche:")
    local search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    search:SetSize(150, 20)
    search:SetPoint("LEFT", sl, "RIGHT", 10, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function() UI.offset = 0; UI:Refresh() end)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    Tip(search, "Durchsucht Name, Notizen, Loot, Fokus und Raidtage.\nz.B. \"dkp\", \"raid\", \"mi\"")
    self.search = search

    -- Filter: Abstaende richten sich nach der Textbreite (nichts ueberlappt)
    self.cbRecruit = MakeCheck(f, "Rekrutiert", "Nur Gilden mit Rekrutierungsnachricht in den letzten 30 Tagen")
    self.cbRecruit:SetPoint("LEFT", search, "RIGHT", 12, 0)
    self.cbFaction = MakeCheck(f, "Meine Fraktion")
    self.cbFaction:SetPoint("LEFT", self.cbRecruit.label, "RIGHT", 12, -1)
    self.cbBlacklist = MakeCheck(f, "Ohne Blacklist")
    self.cbBlacklist:SetPoint("LEFT", self.cbFaction.label, "RIGHT", 12, -1)
    self.cbBlacklist:SetChecked(true)
    self.cbTop = MakeCheck(f, "High Performer", "Nur Gilden mit Leistungswert ab 50 (stark/Top).\nBeim Anklicken wird nach Leistung sortiert.")
    self.cbTop:SetPoint("LEFT", self.cbBlacklist.label, "RIGHT", 12, -1)
    local instBtn = MakeButton(f, "Instanz: alle", 175, 22)
    instBtn:SetPoint("TOPRIGHT", -16, -31)
    instBtn:SetScript("OnClick", function() UI:ToggleInstMenu() end)
    Tip(instBtn, "Nur Gilden zeigen, die in diesem Raid/Dungeon gesehen oder in ihrer Werbung genannt wurden.\nSortiert nach Aktivität (wie oft als Gruppe drin).")
    self.instBtn = instBtn

    for _, cb in ipairs({ self.cbRecruit, self.cbFaction, self.cbBlacklist, self.cbTop }) do
        cb:SetScript("OnClick", function(c)
            if c == UI.cbTop and c:GetChecked() then UI.sortKey, UI.sortDesc = "score", true end
            UI.offset = 0
            UI:Refresh()
        end)
    end

    -- zuletzt gewaehlte Sortierung wiederherstellen
    local gs = ns.db and ns.db.settings.gsSort
    if gs and gs[1] then
        local known = false
        for _, c in ipairs(COLS) do if c.key == gs[1] then known = true end end
        if known or gs[1] == "inst" then self.sortKey, self.sortDesc = gs[1], gs[2] and true or false end
    end
    -- Spaltenkoepfe
    local x = 16
    self.headers = {}
    for _, col in ipairs(COLS) do
        local h = CreateFrame("Button", nil, f)
        h:SetSize(col.w, 18)
        h:SetPoint("TOPLEFT", x, -64)
        local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetJustifyH(col.align or "CENTER")
        h.fs = fs
        h.col = col
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        h:SetScript("OnClick", function()
            if UI.sortKey == col.key then
                UI.sortDesc = not UI.sortDesc
            else
                UI.sortKey = col.key
                UI.sortDesc = col.key ~= "name" and col.key ~= "faction"
            end
            UI:Refresh()
        end)
        self.headers[#self.headers + 1] = h
        x = x + col.w + 2
    end
    local listW = x - 16

    -- Zeilen
    local listArea = CreateFrame("Frame", nil, f)
    listArea:SetPoint("TOPLEFT", 14, -84)
    listArea:SetSize(listW + 4, ROWS * ROW_H)
    listArea:EnableMouseWheel(true)
    listArea:SetScript("OnMouseWheel", function(_, delta)
        UI:SetOffset(UI.offset - delta * 3)
    end)
    self.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, listArea)
        r:SetSize(listW, ROW_H)
        r:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.2, 0.6, 1, 0.25)
        sel:Hide()
        r.sel = sel
        if i % 2 == 0 then
            local bg = r:CreateTexture(nil, "BACKGROUND", nil, -1)
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end
        r.cells = {}
        local cx = 0
        for ci, col in ipairs(COLS) do
            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 2, 0)
            fs:SetSize(col.w - 4, ROW_H)
            fs:SetJustifyH(col.align or "CENTER")
            fs:SetWordWrap(false)
            r.cells[ci] = fs
            cx = cx + col.w + 2
        end
        r:SetScript("OnClick", function(self)
            if self.key then
                UI.selected = self.key
                UI:UpdateRows()
                UI:UpdateDetail()
            end
        end)
        self.rows[i] = r
    end

    -- Scrollbalken
    local slider = CreateFrame("Slider", nil, f, "BackdropTemplate")
    slider:SetOrientation("VERTICAL")
    slider:SetSize(14, ROWS * ROW_H)
    slider:SetPoint("TOPLEFT", listArea, "TOPRIGHT", 2, 0)
    Backdrop(slider)
    slider:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    slider:SetMinMaxValues(0, 0)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetScript("OnValueChanged", function(_, v)
        local o = math.floor(v + 0.5)
        if o ~= UI.offset then
            UI.offset = o
            UI:UpdateRows()
        end
    end)
    self.slider = slider

    self:CreateDetail(f)

    -- Untere Leiste (seit 2.27.0): EIN pinker Knopf "Weiter scannen" - CBAS waehlt die naechste
    -- sinnvolle /who-Abfrage. Daneben ein kleines Menue fuer gezielte Scans; rechts leise die Werkzeuge.
    local T = ns.T
    local function Btn(text, w, kind, parent) return T.Button(parent or f, text, w, 24, kind) end
    local nextBtn = Btn("Weiter scannen", 132, "primary")
    nextBtn:SetPoint("BOTTOMLEFT", 16, 14)
    nextBtn:SetScript("OnClick", function() UI:HideScanMenu() ns.SmartScanStep() end)
    Tip(nextBtn, "Jeder Klick schickt die nächste sinnvolle /who-Abfrage und speichert alle Gilden der Treffer.\nCBAS wechselt selbst ab: Rekrutierer zuordnen, Instanzen, 60er-Gebiete, Level/Klasse, Hauptstädte.\nVolle Gebiete werden automatisch nach Klassen aufgeteilt. Wartezeit 5 s.")
    self.nextBtn = nextBtn
    local menuBtn = Btn("Gezielt ...", 84, "quiet")
    menuBtn:SetPoint("LEFT", nextBtn, "RIGHT", 2, 0)
    menuBtn:SetScript("OnClick", function() UI:ToggleScanMenu() end)
    Tip(menuBtn, "Gezielt scannen: eine bestimmte Scan-Art auswählen.")
    self.menuBtn = menuBtn
    -- zweiter Scan: die angezeigte Liste von oben nach unten per "/who Gilde" abarbeiten
    local listBtn = Btn("Liste scannen", 112, "normal")
    listBtn:SetPoint("LEFT", menuBtn, "RIGHT", 6, 0)
    listBtn:SetScript("OnClick", function() UI:HideScanMenu() UI:ListScanStep() end)
    listBtn:HookScript("OnEnter", function(b)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText("Liste scannen", 1, 1, 1)
        GameTooltip:AddLine("Reihenfolge: " .. UI:ListScanOrderText(), 0.4, 1, 0.4)
        GameTooltip:AddLine("Jeder Klick: /who auf die nächste Gilde - von oben nach unten, so wie DU die Liste sortiert und gefiltert hast. Zum Umstellen einfach auf eine Spaltenüberschrift klicken; dann beginnt der Scan wieder oben.", 1, 1, 1, true)
        GameTooltip:AddLine("Gilden, die in den letzten 6 Std. schon dran waren, werden übersprungen. Am Ende geht es wieder oben los. Wartezeit 5 s.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    listBtn:HookScript("OnLeave", GameTooltip_Hide)
    self.listBtn = listBtn
    local nextLbl = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nextLbl:SetPoint("LEFT", listBtn, "RIGHT", 10, 0)
    nextLbl:SetWidth(210)
    nextLbl:SetJustifyH("LEFT")
    nextLbl:SetWordWrap(false)
    nextLbl:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    self.nextLbl = nextLbl

    -- Menue: die einzelnen Scan-Arten (frueher fuenf Knoepfe in der Leiste)
    local menu = T.Card(f)
    menu:SetSize(236, 168)
    menu:SetPoint("BOTTOMLEFT", nextBtn, "TOPLEFT", 0, 6)
    menu:SetFrameLevel((f:GetFrameLevel() or 1) + 40)
    T.Box(menu, { 0.07, 0.075, 0.09, 0.98 }, T.C.lineHi)
    menu:EnableMouse(true)
    menu:Hide()
    self.scanMenu = menu
    local mh = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mh:SetPoint("TOPLEFT", 10, -8)
    mh:SetText(T.Upper("Gezielt scannen"))
    mh:SetTextColor(T.C.accentHi[1], T.C.accentHi[2], T.C.accentHi[3])
    local function Item(text, y, fn, tip)
        local b = Btn(text, 216, "quiet", menu)
        b:SetPoint("TOPLEFT", 10, y)
        b:SetScript("OnClick", function() UI:HideScanMenu() fn() end)
        Tip(b, tip)
        return b
    end
    self.pendBtn = Item("Unzugeordnet: 0", -26, function() ns.ResolveNextPending() end,
        "Rekrutierungsnachrichten, bei denen kein Gildenname erkennbar war.\nKlick = /who auf den Absender, um seine Gilde zu ermitteln.")
    self.zoneBtn = Item("Instanz-Scan", -52, function() ns.WhoZoneStep() end,
        "/who auf einen Raid oder Dungeon (MC, BWL, ZG ... Strat, Scholo, BRD ... bis Todesminen).\nSind 3+ Mitglieder einer Gilde gleichzeitig drin, zählt das als Gildengruppe.\nNur Raids: /crap dungeons")
    self.z60Btn = Item("60er-Scan", -78, function() ns.WhoZone60Step() end,
        "/who auf alle Level-60-Spieler in einem Endgame-Gebiet (Silithus, Winterquell, Pestländer ...).\nIst ein Gebiet voll (50 Treffer), werden die Klassen einzeln abgefragt.")
    self.scanBtn = Item("Who-Scan", -104, function() ns.WhoScanStep() end,
        "/who nach Levelbereich bzw. Klasse.")
    self.capBtn = Item("Städte", -130, function() ns.WhoCapitalStep() end,
        "/who auf alle Level-60-Spieler in einer Hauptstadt (Orgrimmar, Unterstadt, Donnerfels, Sturmwind, Eisenschmiede, Darnassus).\nAn/aus im Weiter-Scannen-Rundlauf: /crap staedte")
    f:HookScript("OnHide", function() menu:Hide() end)

    local expBtn = Btn("Export", 64, "quiet")
    expBtn:SetPoint("BOTTOMRIGHT", -14, 14)
    expBtn:SetScript("OnClick", function() UI:ShowExport() end)
    Tip(expBtn, "Gildenliste als Text zum Kopieren (z. B. für eine Tabelle).")

    local logBtn = Btn("Chat-Log", 76, "quiet")
    logBtn:SetPoint("RIGHT", expBtn, "LEFT", -2, 0)
    logBtn:SetScript("OnClick", function() UI:ShowChatLog() end)
    Tip(logBtn, "Alle Rekrutierungsnachrichten, die das Addon im Chat erkannt hat - mit zugeordneter Gilde.")

    local curveBtn = Btn("Kurve", 64, "quiet")
    curveBtn:SetPoint("RIGHT", logBtn, "LEFT", -2, 0)
    curveBtn:SetScript("OnClick", function() ns.GuildChart.Toggle() end)
    Tip(curveBtn, "Leistungskurve: alle Gilden der Liste nach Leistungswert sortiert (mit den aktuellen Filtern).\nUmschaltbar auf den Verlauf der besten 10 Gilden über die Tage.")

    local status = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", 18, -450)
    status:SetJustifyH("LEFT")
    self.status = status

    f:Hide()
end

function UI:SetInstFilter(key)
    self.instFilter = key
    self.instBtn:SetText("Instanz: " .. (key and ns.InstanceName(key) or "alle"))
    if key then
        self.sortKey, self.sortDesc = "inst", true
    elseif self.sortKey == "inst" then
        self.sortKey, self.sortDesc = "recruit", true
    end
    if self.instMenu then self.instMenu:Hide() end
    self.offset = 0
    self:Refresh()
end

function UI:ToggleInstMenu()
    if self.instMenu then
        self.instMenu:SetShown(not self.instMenu:IsShown())
        return
    end
    local m = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    m:SetFrameStrata("DIALOG")
    m:SetPoint("TOPRIGHT", self.instBtn, "BOTTOMRIGHT", 0, -2)
    m:SetWidth(200)
    if m.SetBackdrop then
        m:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        m:SetBackdropColor(0.05, 0.05, 0.08, 0.95)
    end
    local y = -6
    local function addLine(text, key, header)
        if header then
            local fs = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("TOPLEFT", 10, y)
            fs:SetText(text)
            y = y - 16
            return
        end
        local b = CreateFrame("Button", nil, m)
        b:SetSize(186, 16)
        b:SetPoint("TOPLEFT", 7, y)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 6, 0)
        fs:SetText(text)
        b:SetScript("OnClick", function() UI:SetInstFilter(key) end)
        y = y - 16
    end
    addLine("Alle Gilden", nil)
    addLine("— Raids —", nil, true)
    for _, inst in ipairs(ns.INSTANCES) do
        if inst.kind == "raid" then addLine(ns.InstanceName(inst.key), inst.key) end
    end
    addLine("— Dungeons —", nil, true)
    for _, inst in ipairs(ns.INSTANCES) do
        if inst.kind == "dungeon" then addLine(ns.InstanceName(inst.key), inst.key) end
    end
    m:SetHeight(-y + 6)
    self.instMenu = m
end

---------------------------------------------------------------------------
-- Detailbereich
---------------------------------------------------------------------------
function UI:CreateDetail(f)
    local d = CreateFrame("Frame", nil, f, "BackdropTemplate")
    d:SetPoint("TOPLEFT", 534, -60)
    d:SetPoint("BOTTOMRIGHT", -12, 42)
    Backdrop(d)
    self.detail = d

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetPoint("TOPRIGHT", -10, -8)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    self.dTitle = title

    -- Reiter: Profil / Mitglieder / Chat
    self.tab = "profile"
    self.tabBtns = {}
    local tabs = { { "profile", "Profil" }, { "members", "Mitglieder" }, { "chat", "Nachrichten" } }
    for i, t in ipairs(tabs) do
        local b = MakeButton(d, t[2], 92, 20)
        b:SetPoint("TOPLEFT", 8 + (i - 1) * 96, -30)
        b:SetScript("OnClick", function()
            UI.tab = t[1]
            UI.dScroll:SetVerticalScroll(0)
            UI:UpdateDetail()
        end)
        b.tabKey = t[1]
        self.tabBtns[i] = b
    end

    local sf = CreateFrame("ScrollFrame", nil, d, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 8, -54)
    sf:SetPoint("TOPRIGHT", -28, -54)
    sf:SetHeight(201)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(270, 10)
    sf:SetScrollChild(child)
    local info = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT")
    info:SetWidth(270)
    info:SetJustifyH("LEFT")
    info:SetJustifyV("TOP")
    info:SetSpacing(2)
    self.dInfo, self.dChild, self.dScroll = info, child, sf

    -- Wertung
    local rl = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rl:SetPoint("TOPLEFT", 10, -265)
    rl:SetText("Wertung:")
    self.rateBtns = {}
    for i = 0, 5 do
        local b = MakeButton(d, i == 0 and "-" or tostring(i), 26, 20)
        b:SetPoint("LEFT", rl, "RIGHT", 6 + i * 28, 0)
        b:SetScript("OnClick", function()
            local g = UI:Sel()
            if g then g.rating = i; UI:Refresh() end
        end)
        self.rateBtns[i] = b
    end

    -- Loot manuell
    local ll = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ll:SetPoint("TOPLEFT", 10, -292)
    ll:SetText("Loot (manuell):")
    local le = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
    le:SetSize(180, 20)
    le:SetPoint("LEFT", ll, "RIGHT", 10, 0)
    le:SetAutoFocus(false)
    le:SetScript("OnEscapePressed", le.ClearFocus)
    le:SetScript("OnEnterPressed", le.ClearFocus)
    le:SetScript("OnTextChanged", function(self, user)
        local g = user and UI:Sel()
        if g then g.lootManual = self:GetText(); UI:QueueListUpdate() end
    end)
    self.dLoot = le

    -- Notizen
    local nl = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nl:SetPoint("TOPLEFT", 10, -316)
    nl:SetText("Notizen:")
    local nbox = CreateFrame("Frame", nil, d, "BackdropTemplate")
    nbox:SetPoint("TOPLEFT", 8, -330)
    nbox:SetPoint("TOPRIGHT", -8, -330)
    nbox:SetHeight(70)
    Backdrop(nbox)
    local nsf = CreateFrame("ScrollFrame", nil, nbox, "UIPanelScrollFrameTemplate")
    nsf:SetPoint("TOPLEFT", 6, -6)
    nsf:SetPoint("BOTTOMRIGHT", -26, 6)
    local ne = CreateFrame("EditBox", nil, nsf)
    ne:SetMultiLine(true)
    ne:SetAutoFocus(false)
    ne:SetFontObject("ChatFontNormal")
    ne:SetWidth(250)
    ne:SetMaxLetters(1000)
    ne:SetScript("OnEscapePressed", ne.ClearFocus)
    ne:SetScript("OnTextChanged", function(self, user)
        local g = user and UI:Sel()
        if g then g.notes = self:GetText() end
    end)
    nsf:SetScrollChild(ne)
    nbox:EnableMouse(true)
    nbox:SetScript("OnMouseDown", function() ne:SetFocus() end)
    self.dNotes = ne

    -- Aktionen
    local fav = MakeButton(d, "Favorit", 70)
    fav:SetPoint("TOPLEFT", 8, -408)
    fav:SetScript("OnClick", function()
        local g = UI:Sel()
        if g then g.favorite = not g.favorite or nil; UI:Refresh() end
    end)
    self.dFav = fav

    local bl = MakeButton(d, "Blacklist", 70)
    bl:SetPoint("LEFT", fav, "RIGHT", 4, 0)
    bl:SetScript("OnClick", function()
        local g = UI:Sel()
        if g then g.blacklist = not g.blacklist or nil; UI:Refresh() end
    end)
    self.dBL = bl

    local who = MakeButton(d, "/who Gilde", 80)
    self.dWho = who
    who:SetPoint("LEFT", bl, "RIGHT", 4, 0)
    who:SetScript("OnClick", function()
        local g = UI:Sel()
        if not g then return end
        if g.pseudo then ns.ResolveNextPending(g.pseudo) else ns.WhoGuild(UI.selected) end
    end)
    Tip(who, "Zeigt, wie viele Mitglieder gerade online sind, und erfasst sie (max. 50).")

    local tell = MakeButton(d, "Anflüstern", 80)
    tell:SetPoint("TOPLEFT", fav, "BOTTOMLEFT", 0, -4)
    tell:SetScript("OnClick", function()
        local g = UI:Sel()
        if not g then return end
        local target = g.recruit.lastFrom or g.leader
        if not target then ns.Print("Kein Ansprechpartner bekannt.") return end
        if ChatFrameUtil and ChatFrameUtil.SendTell then
            ChatFrameUtil.SendTell(target)
        elseif ChatFrame_SendTell then
            ChatFrame_SendTell(target)
        end
    end)
    Tip(tell, "Öffnet ein Flüsterfenster zum letzten Rekrutierer (sonst Gildenmeister).")
    self.dTell = tell

    local del = MakeButton(d, "Löschen", 70)
    del:SetPoint("LEFT", tell, "RIGHT", 4, 0)
    del:SetScript("OnClick", function()
        local g = UI:Sel()
        if g and g.pseudo then
            ns.db.pending[g.pseudo] = nil
            UI.selected = nil
            UI:Refresh()
        elseif g then
            StaticPopup_Show("CBAS_DELETE", g.name, nil, UI.selected)
        end
    end)

    self.detailWidgets = { fav, bl, who, tell, del, le, ne }
end

StaticPopupDialogs["CBAS_DELETE"] = {
    text = "Gilde <%s> aus der CBAS-Datenbank löschen?",
    button1 = YES or "Ja",
    button2 = NO or "Nein",
    OnAccept = function(self, data)
        data = data or (self and self.data)
        if data and ns.db.guilds[data] then
            ns.db.guilds[data] = nil
            UI.selected = nil
            UI:Refresh()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function UI:DetailText(g)
    local L = {}
    local function add(s) L[#L + 1] = s end
    local atMax, avg, active, classes = ns.Stats(g)
    local maxLvl = ns.MaxLevel()

    if ns.PerformanceScore and not g.pseudo then
        local sc, label, parts, unsure = ns.PerformanceScore(g)
        local st = ns.ScoreText(g)
        add(string.format("|cffffd100Leistung:|r %s/100 %s%s", st, label ~= "-" and ("(" .. label .. ")") or "",
            unsure and " |cff888888- noch wenig Daten|r" or ""))
        for _, p in ipairs(parts) do
            if p.v > 0 or p.max >= 15 then
                add(string.format("  |cff888888%s %d/%d:|r %s", p.name, math.floor(p.v + 0.5), p.max, p.txt))
            end
        end
        if g.progress and next(g.progress) then
            local pr = {}
            for k, p in pairs(g.progress) do pr[#pr + 1] = { txt = ns.InstanceName(k) .. " " .. p.txt, tier = ns.RAID_TIER[k] or 0 } end
            table.sort(pr, function(a, b) return a.tier > b.tier end)
            local t = {}
            for _, x in ipairs(pr) do t[#t + 1] = x.txt end
            add("  |cff888888Fortschritt (Werbung):|r " .. table.concat(t, ", "))
        end
        local tops = ns.TopPlayers(g, 5)
        if #tops > 0 then
            local t = {}
            for _, x in ipairs(tops) do
                t[#t + 1] = UI:MemberName(x.full, x.m) .. (x.m.ilvl and (" " .. x.m.ilvl) or "") .. (x.m.pvp and (" |cffcccccc" .. x.m.pvp .. "|r") or "")
            end
            add("  |cff888888Top-Spieler:|r " .. table.concat(t, ", "))
        end
        add(" ")
    end
    add("|cffaaaaaaRealm:|r " .. (g.realm or "?") .. "   |cffaaaaaaFraktion:|r " ..
        (g.faction == "Alliance" and "Allianz" or g.faction == "Horde" and "Horde" or "?"))
    if g.unverified then add("|cffff9900Name nur aus Chat erkannt (noch kein Mitglied gesehen)|r") end
    if g.pseudo then
        add("|cffff9900Rekrutierung erkannt, aber kein Gildenname in der Nachricht.|r")
        add("|cffff9900Klick auf \"/who Gilde\" ermittelt die Gilde von " .. g.pseudo .. " (muss online sein).|r")
        add("|cffff9900Oder fahre einmal mit der Maus über den Spieler.|r")
    end
    if g.shared and g.shared > 0 then
        add("|cff66ccffDaten auch von " .. g.shared .. " anderen Spielern erhalten (Sync).|r")
    end
    if g.inspect and g.inspect.members then
        add(string.format("|cffaaaaaaGildengröße:|r |cff40ff40%d Mitglieder|r |cff888888(echt, per Inspektion vor %s)|r",
            g.inspect.members, ns.Ago(g.inspect.t)))
        if g.inspect.points and g.inspect.points > 0 then
            add("|cffaaaaaaGilden-Erfolgspunkte:|r " .. g.inspect.points)
        end
    else
        add("|cffaaaaaaGildengröße:|r |cff888888unbekannt - ein Mitglied anvisieren (in der Nähe), dann wird sie ermittelt|r")
    end
    add(string.format("|cffaaaaaaMitglieder gesehen:|r %d  (letzte 7 Tage: %d)", g.memberCount, active))
    add(string.format("|cffaaaaaaAuf Level %d:|r %d   |cffaaaaaaØ Level:|r %.0f", maxLvl, atMax, avg))
    local xs = ns.ExtStats(g)
    local b = xs.brackets
    if b[1] + b[2] + b[3] + b[4] > 0 then
        add(string.format("|cffaaaaaaLevel:|r %d: %d · %d-%d: %d · %d-%d: %d · darunter: %d",
            maxLvl, b[1], maxLvl - 10, maxLvl - 1, b[2], maxLvl - 20, maxLvl - 11, b[3], b[4]))
    end
    if xs.ilvlN > 0 then
        add(string.format("|cffaaaaaaØ Itemlevel:|r %.0f |cff888888(%d inspiziert)|r", xs.ilvlSum / xs.ilvlN, xs.ilvlN))
    end
    local function top(tbl, n, map)
        local l = {}
        for k, v in pairs(tbl) do l[#l + 1] = { k = k, v = v } end
        table.sort(l, function(x, y) return x.v > y.v end)
        local out = {}
        for i = 1, math.min(n, #l) do out[#out + 1] = (map and map(l[i].k) or l[i].k) .. " " .. l[i].v end
        return table.concat(out, ", ")
    end
    if next(xs.roles) then
        add("|cffaaaaaaRollen (inspiziert):|r " .. top(xs.roles, 3, function(r)
            return r == "TANK" and "Tank" or r == "HEALER" and "Heiler" or r == "DAMAGER" and "DD" or r end))
    end
    if next(xs.specs) then add("|cffaaaaaaSpezialisierungen:|r " .. top(xs.specs, 6)) end
    if next(xs.races) then add("|cffaaaaaaVölker:|r " .. top(xs.races, 5)) end
    if next(xs.pvp) then add("|cffaaaaaaPvP-Titel:|r " .. top(xs.pvp, 5)) end
    local act = ns.ActivitySummary(g)
    if act then add("|cffaaaaaaOnline:|r " .. act) end
    if g.whoTime then
        add(string.format("|cffaaaaaa/who online:|r %d%s (vor %s, max. %d)", g.whoOnline or 0,
            g.whoCapped and "+" or "", ns.Ago(g.whoTime), g.whoMaxOnline or 0))
    end
    if g.finder and g.finder.members then
        add("|cffaaaaaaGildenfinder:|r " .. g.finder.members .. " aktive Mitglieder")
    end
    if g.statedSize then add("|cffaaaaaaEigene Angabe:|r " .. g.statedSize .. " Mitglieder") end
    -- Raids & Dungeons
    local il = ns.InstanceLines(g)
    if #il > 0 then
        add(" ")
        add("|cffffd100Raids & Dungeons|r")
        for _, l in ipairs(il) do add(l) end
    end

    local mz = ns.MemberZones(g)
    if #mz > 0 then
        local parts = {}
        for i = 1, math.min(5, #mz) do parts[#parts + 1] = mz[i].z .. " " .. mz[i].n end
        add("|cffaaaaaaUnterwegs in:|r " .. table.concat(parts, ", "))
    end

    -- Fuehrung & Ansprechpartner
    add(" ")
    add("|cffffd100Führung|r")
    local gm = g.leader or (g.finder and g.finder.leader)
    if gm then
        local m = g.members[gm]
        add("|cffaaaaaaGildenmeister:|r " .. UI:MemberName(gm, m) .. (m and m.seen and (" |cff888888(gesehen vor " .. ns.Ago(m.seen) .. ")|r") or ""))
    else
        add("|cffaaaaaaGildenmeister:|r |cff888888noch nicht gesehen|r")
    end
    local officers = {}
    for full, m in pairs(g.members) do
        if m.rankIndex == 1 then officers[#officers + 1] = UI:MemberName(full, m) end
    end
    table.sort(officers)
    if #officers > 0 then
        add("|cffaaaaaa" .. (g.ranks[1] or "Offiziere") .. ":|r " .. table.concat(officers, ", "))
    end
    local contacts = {}
    for full, info in pairs(g.recruit.recruiters or {}) do
        local t = type(info) == "table" and info.t or info
        local cls = type(info) == "table" and info.class or (g.members[full] and g.members[full].class)
        contacts[#contacts + 1] = { full = full, t = t or 0, class = cls }
    end
    table.sort(contacts, function(a, b) return a.t > b.t end)
    if #contacts > 0 then
        local parts = {}
        for i = 1, math.min(6, #contacts) do
            local c = contacts[i]
            parts[#parts + 1] = (c.class and ClassColor(c.class) or "|cffffffff") .. ns.SplitName(c.full) .. "|r"
        end
        add("|cffaaaaaaRekrutierer:|r " .. table.concat(parts, ", "))
    end
    local ranks = {}
    for i = 0, g.maxRankIndex do
        if g.ranks[i] then ranks[#ranks + 1] = g.ranks[i] end
    end
    if #ranks > 0 then
        add("|cffaaaaaaRänge (" .. (g.maxRankIndex + 1) .. "+):|r " .. table.concat(ranks, ", "))
    end
    local cl = {}
    for file, n in pairs(classes) do cl[#cl + 1] = { file = file, n = n } end
    table.sort(cl, function(a, b) return a.n > b.n end)
    if #cl > 0 then
        local parts = {}
        for _, c in ipairs(cl) do parts[#parts + 1] = ClassColor(c.file) .. ClassName(c.file) .. "|r " .. c.n end
        add("|cffaaaaaaKlassen:|r " .. table.concat(parts, ", "))
    end

    add(" ")
    local r = g.recruit
    if r.last then
        local active30 = ns.IsRecruiting(g)
        add(string.format("|cffaaaaaaRekrutierung:|r %s, zuletzt vor %s (%d versch. Texte, %d Posts)",
            active30 and "|cff40ff40aktiv|r" or "|cffff9900älter|r", ns.Ago(r.last), r.count or 0, r.posts or 0))
    else
        add("|cffaaaaaaRekrutierung:|r keine gesehen")
    end
    -- Lootsystem mit Hinweisen und Sicherheit
    local ll = ns.LootLines and ns.LootLines(g) or {}
    if #ll > 0 then
        add("|cffffd100Lootsystem|r")
        for _, l in ipairs(ll) do add("  " .. l) end
    else
        add("|cffffd100Lootsystem:|r |cff888888unbekannt - Hinweise kommen aus Werbung, Chat der Mitglieder und gemeinsamen Runs|r")
    end
    if g.days or g.times then
        add("|cffaaaaaaRaidzeiten:|r " .. (g.days or "") .. ((g.days and g.times) and " · " or "") .. (g.times or ""))
    end
    local tags = {}
    for t in pairs(g.tags) do tags[#tags + 1] = t end
    table.sort(tags)
    if #tags > 0 then add("|cffaaaaaaFokus:|r " .. table.concat(tags, ", ")) end
    local wanted = {}
    for w in pairs(g.wanted) do
        wanted[#wanted + 1] = ROLE_NAMES[w] or (ClassColor(w) .. ClassName(w) .. "|r")
    end
    table.sort(wanted)
    if #wanted > 0 then add("|cffaaaaaaSucht:|r " .. table.concat(wanted, ", ")) end
    if g.lang then
        add("|cffaaaaaaSprache:|r " .. (ns.LANG_NAMES[g.lang] or g.lang) ..
            (g.langTag and " |cff888888(in der Werbung angegeben)|r" or " |cff888888(aus den Texten erkannt)|r"))
    end
    if g.countries and next(g.countries) then add("|cffaaaaaaLänder:|r " .. ns.CountryList(g)) end
    if g.region then add("|cffaaaaaaRegion:|r " .. g.region) end
    if g.finder and g.finder.comment and g.finder.comment ~= "" then
        add("|cffaaaaaaGildenfinder-Text:|r " .. g.finder.comment)
    end
    if g.layerSeen and next(g.layerSeen) and ns.Layer then
        local t = {}
        for lk, ts in pairs(g.layerSeen) do
            local zone, key = lk:match("^(.-)|(.+)$")
            local n = zone and ns.Layer.Number(zone, key)
            t[#t + 1] = { txt = (n and ("#" .. n) or "?") .. " " .. (zone or ""), ts = ts }
        end
        table.sort(t, function(a, b) return a.ts > b.ts end)
        local parts = {}
        for i = 1, math.min(4, #t) do parts[#parts + 1] = t[i].txt .. " (vor " .. ns.Ago(t[i].ts) .. ")" end
        add("|cffaaaaaaPer /who gesehen auf Layer:|r " .. table.concat(parts, ", "))
    end
    add("|cffaaaaaaErstmals:|r " .. Date(g.firstSeen) .. "   |cffaaaaaaZuletzt:|r " .. Date(g.lastSeen))
    return table.concat(L, "\n")
end

function UI:MemberName(full, m)
    local name, realm = ns.SplitName(full)
    if realm and realm ~= ns.MyRealm() then name = name .. "|cff888888-" .. realm .. "|r" end
    if m and m.class then return ClassColor(m.class) .. name .. "|r" end
    return name
end

-- Mitgliederliste, gruppiert nach Rang
function UI:MembersText(g)
    local list = {}
    for full, m in pairs(g.members) do list[#list + 1] = { full = full, m = m } end
    if #list == 0 then
        return "|cff888888Noch keine Mitglieder gesehen.\n\nTipp: \"/who Gilde\" klicken oder Spieler mit der Maus berühren.|r"
    end
    table.sort(list, function(a, b)
        local ra, rb = a.m.rankIndex or 99, b.m.rankIndex or 99
        if ra ~= rb then return ra < rb end
        local la, lb = a.m.level or 0, b.m.level or 0
        if la ~= lb then return la > lb end
        return a.full < b.full
    end)
    local L = { string.format("|cffffd100%d Mitglieder gesehen|r |cff888888(Name · Level · Klasse · zuletzt gesehen · Ort)|r", #list) }
    local lastRank = -1
    local shown = 0
    for _, e in ipairs(list) do
        local m = e.m
        local ri = m.rankIndex or 99
        if ri ~= lastRank then
            lastRank = ri
            local rn
            if ri == 99 then rn = "Rang unbekannt (über /who erfasst)"
            elseif ri == 0 then rn = (g.ranks[0] or "Gildenmeister")
            else rn = g.ranks[ri] or ("Rang " .. ri) end
            L[#L + 1] = " "
            L[#L + 1] = "|cffffd100— " .. rn .. " —|r"
        end
        shown = shown + 1
        if shown > 250 then
            L[#L + 1] = "|cff888888... und " .. (#list - 250) .. " weitere (siehe Export)|r"
            break
        end
        local extra = {}
        if m.spec then extra[#extra + 1] = m.spec end
        if m.ilvl then extra[#extra + 1] = "iLvl " .. m.ilvl end
        if m.pvp then extra[#extra + 1] = m.pvp end
        L[#L + 1] = string.format("%s  %s %s%s  |cff888888vor %s%s|r",
            UI:MemberName(e.full, m),
            m.level and tostring(m.level) or "?",
            m.class and ClassName(m.class) or "",
            #extra > 0 and (" |cffcccccc(" .. table.concat(extra, ", ") .. ")|r") or "",
            ns.Ago(m.seen),
            m.zone and (" · " .. m.zone) or "")
    end
    return table.concat(L, "\n")
end

function UI:ChatText(g)
    local r = g.recruit
    if #r.msgs == 0 then return "|cff888888Noch keine Rekrutierungsnachricht dieser Gilde gesehen.|r" end
    local L = { "|cffffd100Letzte Rekrutierungsnachrichten|r" }
    for _, m in ipairs(r.msgs) do
        L[#L + 1] = " "
        L[#L + 1] = string.format("|cff888888[%s] %s%s:|r", date("%d.%m. %H:%M", m.t),
            (m.class and ClassColor(m.class) or "|cffffffff") .. ns.SplitName(m.from) .. "|r",
            m.ch and (" |cff888888(" .. m.ch .. ")|r") or "")
        L[#L + 1] = m.text
    end
    return table.concat(L, "\n")
end

function UI:UpdateDetail()
    if not self.frame then return end
    self:UpdateDetailInner()
    self:UpdateCooldowns()
end

function UI:UpdateDetailInner()
    local g = self:Sel()
    local enabled = g ~= nil
    for _, w in ipairs(self.detailWidgets) do
        if w.SetEnabled then w:SetEnabled(enabled) end
    end
    for i = 0, 5 do
        local b = self.rateBtns[i]
        b:SetEnabled(enabled)
        if g and (g.rating or 0) == i then b:LockHighlight() else b:UnlockHighlight() end
    end
    if g and g.pseudo then
        -- Platzhalter: nur /who (Gilde ermitteln), Anfluestern und Loeschen
        for _, w in ipairs({ self.dFav, self.dBL, self.dLoot, self.dNotes }) do w:SetEnabled(false) end
        for i = 0, 5 do self.rateBtns[i]:SetEnabled(false) end
    end
    if not g then
        self.dTitle:SetText("|cff888888Gilde auswählen|r")
        self.dInfo:SetText("Wähle links eine Gilde aus.\n\nDaten werden automatisch gesammelt, wenn du\n- Spieler mit der Maus berührst oder anvisierst\n- in einer Gruppe/einem Raid bist\n- Namensplaketten siehst\n- /who benutzt (oder Who-Scan klickst)\n- Rekrutierungen im Chat (Handel, Allgemein, Suche nach Gruppe, Rufen) auftauchen")
        self.dChild:SetHeight(self.dInfo:GetStringHeight() + 10)
        if not self.dNotes:HasFocus() then self.dNotes:SetText("") end
        if not self.dLoot:HasFocus() then self.dLoot:SetText("") end
        return
    end
    local prefix = g.favorite and "|cffffd100* |r" or ""
    if g.blacklist then prefix = "|cffff4040[BL] |r" end
    if g.pseudo then
        self.dTitle:SetText("|cffaaaaaaGilde unbekannt|r")
    else
        self.dTitle:SetText(prefix .. "<" .. g.name .. ">")
    end
    local text
    if self.tab == "members" then text = self:MembersText(g)
    elseif self.tab == "chat" then text = self:ChatText(g)
    else text = self:DetailText(g) end
    self.dInfo:SetText(text)
    for _, b in ipairs(self.tabBtns) do
        if b.tabKey == self.tab then b:LockHighlight() else b:UnlockHighlight() end
    end
    self.tabBtns[2]:SetText("Mitglieder (" .. g.memberCount .. ")")
    self.tabBtns[3]:SetText("Nachrichten (" .. #g.recruit.msgs .. ")")
    self.dChild:SetHeight(self.dInfo:GetStringHeight() + 10)
    if self.lastDetailKey ~= self.selected then
        self.dScroll:SetVerticalScroll(0)
        self.dNotes:SetText(g.notes or "")
        self.dLoot:SetText(g.lootManual or "")
        self.lastDetailKey = self.selected
    else
        if not self.dNotes:HasFocus() then self.dNotes:SetText(g.notes or "") end
        if not self.dLoot:HasFocus() then self.dLoot:SetText(g.lootManual or "") end
    end
    self.dFav:SetText(g.favorite and "Kein Fav." or "Favorit")
    self.dBL:SetText(g.blacklist and "Entsperren" or "Blacklist")
end

---------------------------------------------------------------------------
-- Liste zeichnen
---------------------------------------------------------------------------
function UI:SetOffset(o)
    local maxO = math.max(0, #self.list - ROWS)
    o = math.max(0, math.min(maxO, o))
    self.offset = o
    self.slider:SetValue(o)
    self:UpdateRows()
end

function UI:UpdateRows()
    local maxLvl = ns.MaxLevel()
    for i = 1, ROWS do
        local row = self.rows[i]
        local e = self.list[self.offset + i]
        if e then
            local g = e.g
            row.key = e.key
            local name = g.name
            if g.blacklist then
                name = "|cff777777" .. name .. "|r"
            elseif g.favorite then
                name = "|cffffd100" .. name .. "|r"
            end
            if g.unverified then name = name .. " |cffff9900?|r" end
            if g.pseudo then name = "|cffaaaaaa" .. g.name .. "|r" end
            row.cells[1]:SetText(name)
            row.cells[2]:SetText(FactionTag(g.faction))
            local lt = ns.LangTag(g)
            row.cells[3]:SetText(lt ~= "" and ("|cff99ccff" .. lt .. "|r") or "|cff555555-|r")
            if g.inspect and g.inspect.members then
                -- echte Groesse (aus Inspektion) gruen, gesehene grau
                row.cells[4]:SetText("|cff40ff40" .. g.inspect.members .. "|r|cff888888/" .. g.memberCount .. "|r")
            else
                local whoTxt = g.whoMaxOnline and g.whoMaxOnline > g.memberCount and ("|cff888888/" .. g.whoMaxOnline .. "|r") or ""
                row.cells[4]:SetText(g.memberCount .. whoTxt)
            end
            row.cells[5]:SetText(e.atMax > 0 and ("|cffffffff" .. e.atMax .. "|r") or "|cff555555-|r")
            row.cells[6]:SetText(e.scoreText or "|cff555555-|r")
            if ns.IsRecruiting(g, 7) then
                row.cells[7]:SetText("|cff40ff40" .. ns.Ago(g.recruit.last) .. "|r")
            elseif ns.IsRecruiting(g, 30) then
                row.cells[7]:SetText("|cffffff00" .. ns.Ago(g.recruit.last) .. "|r")
            elseif g.recruit.last then
                row.cells[7]:SetText("|cff888888" .. ns.Ago(g.recruit.last) .. "|r")
            else
                row.cells[7]:SetText("|cff555555-|r")
            end
            row.cells[8]:SetText((UI.WantedIcons(g)) or "|cff555555-|r")
            local loot = ns.LootString(g)
            row.cells[9]:SetText(loot ~= "" and loot or "|cff555555-|r")
            row.cells[10]:SetText((g.rating or 0) > 0 and ("|cffffd100" .. g.rating .. "/5|r") or "|cff555555-|r")
            if self.selected == e.key then row.sel:Show() else row.sel:Hide() end
            row:Show()
        else
            row.key = nil
            row:Hide()
        end
    end
end

-- Normale Beschriftung der Scan-Knoepfe
---------------------------------------------------------------------------
-- "Liste scannen": angezeigte Liste von oben nach unten per /who abarbeiten (seit 2.29.0)
---------------------------------------------------------------------------
UI.LIST_FRESH = 6 * 3600   -- Gilden, die so frisch gescannt sind, werden uebersprungen

function UI:ListScanState()
    ns.db.settings.listScan = ns.db.settings.listScan or {}
    return ns.db.settings.listScan
end

local SORT_NAMES = { name = "Name", faction = "Fraktion", lang = "Sprache", members = "Größe", max = "60er", score = "Leistung",
    recruit = "Rekrutierung", wanted = "gesuchte Klassen", loot = "Loot", rating = "Wertung", inst = "Instanz" }

-- Kennung der aktuellen Sortierung + Filter: aendert sie sich, beginnt der Listen-Scan wieder oben
function UI:ListScanSig()
    local function on(cb) return cb and cb:GetChecked() and "1" or "0" end
    return table.concat({ self.sortKey or "", self.sortDesc and "d" or "a", (self.search and self.search:GetText() or ""):lower(),
        on(self.cbRecruit), on(self.cbFaction), on(self.cbBlacklist), on(self.cbTop), self.instFilter or "" }, "|")
end

function UI:ListScanOrderText()
    return "nach " .. (SORT_NAMES[self.sortKey] or self.sortKey or "?") .. (self.sortDesc and " (absteigend)" or " (aufsteigend)")
end

-- Reihenfolge einmal festhalten, damit neue Scan-Ergebnisse die Liste waehrend des Durchlaufs nicht umwerfen
function UI:ListScanOrder()
    local st = self:ListScanState()
    local sig = self:ListScanSig()
    local o = self.scanOrder
    if not o or o.sig ~= sig then
        if not self.list or #self.list == 0 then self:BuildList() end
        o = { sig = sig, keys = {} }
        for i, e in ipairs(self.list or {}) do o.keys[i] = e.key end
        self.scanOrder = o
        if st.sig ~= sig then st.sig, st.key, st.pos = sig, nil, 0 end
    end
    return o.keys
end

-- Position der zuletzt gescannten Gilde (0 = noch keine)
function UI:ListScanPos()
    local st = self:ListScanState()
    local keys = self:ListScanOrder()
    if st.key then
        for i, k in ipairs(keys) do if k == st.key then return i end end
    end
    return math.min(st.pos or 0, #keys)
end

function UI:ListScanLabel()
    local keys = self:ListScanOrder()
    if #keys == 0 then return "Liste scannen" end
    return string.format("Liste %d/%d", self:ListScanPos(), #keys)
end

function UI:ListScanStep()
    local keys = self:ListScanOrder()
    if #keys == 0 then ns.Print("Die Liste ist leer - Filter prüfen.") return end
    local st = self:ListScanState()
    local start = self:ListScanPos() + 1
    local now = time()
    for step = 0, #keys - 1 do
        local i = ((start - 1 + step) % #keys) + 1
        local key = keys[i]
        local g = ns.db.guilds[key]
        if g and not g.pseudo and now - (g.whoScanT or 0) >= UI.LIST_FRESH then
            local before = ns.lastWho
            ns.WhoGuild(key)
            if ns.lastWho ~= before then
                g.whoScanT = now
                st.key, st.pos = key, i
                -- Zeile markieren und sichtbar machen (Position in der aktuell angezeigten Liste)
                self.selected = key
                self:BuildList()
                for j, e in ipairs(self.list) do
                    if e.key == key then
                        if j <= self.offset or j > self.offset + ROWS then self.offset = math.max(0, j - 3) end
                        break
                    end
                end
                self:Refresh()
            end
            return
        end
    end
    ns.Print("Liste komplett: alle angezeigten Gilden wurden in den letzten 6 Std. schon gescannt.")
end

function UI:ToggleScanMenu()
    if not self.scanMenu then return end
    self.scanMenu:SetShown(not self.scanMenu:IsShown())
    if self.scanMenu:IsShown() then self:UpdateScanLabels() end
end
function UI:HideScanMenu() if self.scanMenu then self.scanMenu:Hide() end end

function UI:UpdateScanLabels()
    if self.nextLbl and ns.SmartScanLabel then
        local ok, txt = pcall(ns.SmartScanLabel)
        self.nextLbl:SetText(ok and ("als Nächstes: " .. txt) or "")
    end
    if self.nextBtn and not self.cdActive then self.nextBtn:SetText("Weiter scannen") end
    if self.listBtn and not self.cdActive then self.listBtn:SetText(self:ListScanLabel()) end
    self.pendBtn:SetText("Rekrutierer zuordnen (" .. ns.PendingCount() .. ")")
    if ns.scanSteps then
        self.scanBtn:SetText(string.format("Level/Klasse %d/%d", ns.scanIndex or 1, #ns.scanSteps))
    end
    if ns.ZoneScanList then
        local zl = ns.ZoneScanList()
        local zi = math.min(ns.zoneIndex or 1, #zl)
        self.zoneBtn:SetText("Instanz: " .. (zl[zi] and zl[zi].key or "?") .. " (" .. zi .. "/" .. #zl .. ")")
    end
    if ns.CurrentCapital and self.capBtn then
        local z, split = ns.CurrentCapital()
        self.capBtn:SetText("Hauptstadt: " .. (z or "?") .. (split and " (Klassen)" or ""))
    end
    if ns.CurrentZone60 then
        local z, split = ns.CurrentZone60()
        self.z60Btn:SetText("60er-Gebiet: " .. (z or "?") .. (split and " (Klassen)" or ""))
    end
end

-- Knoepfe mit /who-Sperre: ausgrauen und herunterzaehlen
function UI:UpdateCooldowns()
    if not self.scanBtn then return end
    local rem = ns.WhoCooldown()
    local btns = {
        { self.nextBtn, "Weiter scannen" }, { self.listBtn, "Liste" }, { self.scanBtn, "Who" }, { self.zoneBtn, "Inst" }, { self.z60Btn, "60er" },
        { self.capBtn, "Stadt" }, { self.pendBtn, "Zuordnen" }, { self.dWho, "/who" },
    }
    if rem > 0 then
        local s = math.ceil(rem)
        for _, b in ipairs(btns) do
            b[1]:SetEnabled(false)
            b[1]:SetText(string.format("%s |cffffd100%ds|r", b[2], s))
        end
        self.cdActive = true
    elseif self.cdActive then
        self.cdActive = false
        for i = 1, #btns - 1 do btns[i][1]:SetEnabled(true) end
        self.dWho:SetText("/who Gilde")
        self.dWho:SetEnabled(self:Sel() ~= nil)
        self:UpdateScanLabels()
    end
end

function UI:Refresh()
    if not self.frame or not self.frame:IsVisible() then return end
    if ns.db and ns.db.settings then ns.db.settings.gsSort = { self.sortKey, self.sortDesc and true or false } end
    self:BuildList()
    local maxO = math.max(0, #self.list - ROWS)
    if self.offset > maxO then self.offset = maxO end
    self.slider:SetMinMaxValues(0, maxO)
    self.slider:SetValue(self.offset)
    for _, h in ipairs(self.headers) do
        local arrow = ""
        if h.col.key == self.sortKey then arrow = self.sortDesc and " v" or " ^" end
        h.fs:SetText(h.col.label .. arrow)
    end
    self:UpdateRows()
    self:UpdateDetail()
    local total = 0
    for _ in pairs(ns.db.guilds) do total = total + 1 end
    local layer = ns.Layer and (ns.Layer.cur and ("Auslesen auf Layer " .. (ns.Layer.Label(ns.Layer.cur)) .. " (" .. ns.Layer.cur.zone .. ")")
        or "Layer unbekannt - NPC anvisieren") or ""
    self.status:SetText(string.format("%d Gilden · %d rekrut. · %d angez. · %s\nChat: %d gelesen, %d erkannt · %s",
        total, self.totalRecruit or 0, #self.list, layer, ns.chatSeen or 0, ns.chatHits or 0,
        ns.Sync and ns.Sync:StatusText() or ""))
    self:UpdateScanLabels()
    self:UpdateCooldowns()
end

function UI:QueueListUpdate()
    if self.queued then return end
    self.queued = true
    C_Timer.After(0.5, function()
        UI.queued = false
        if UI.frame and UI.frame:IsVisible() then
            UI:BuildList()
            UI:UpdateRows()
        end
    end)
end

-- Von Core/Parser aufgerufen (gedrosselt)
function ns.RefreshUI()
    if not UI.frame or not UI.frame:IsVisible() or UI.refreshQueued then return end
    UI.refreshQueued = true
    C_Timer.After(3, function()
        UI.refreshQueued = false
        UI:Refresh()
    end)
end

function UI:Toggle()
    ns.Suite:Toggle()
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------
local function csv(v)
    v = tostring(v or "")
    v = v:gsub("[\r\n]+", " "):gsub(";", ",")
    return v
end

function UI:ShowChatLog()
    local log = ns.db.chatlog
    local lines = {
        "==== DIAGNOSE (diese Sitzung) ====",
        string.format("Chat-Ereignisse empfangen: %d | lesbar: %d | gesperrt (Secret): %d | in Instanz ignoriert: %d",
            ns.chatEvents or 0, ns.chatSeen or 0, ns.chatSecret or 0, ns.chatInInstance or 0),
        string.format("Als Rekrutierung erkannt: %d | Fehler: %d%s", ns.chatHits or 0, ns.chatErrors or 0,
            ns.lastChatError and (" (letzter: " .. ns.lastChatError .. ")") or ""),
        "Realm laut Addon: " .. tostring(ns.MyRealm()) .. " | Chat-Erkennung: " .. (ns.db.settings.chatScan and "an" or "AUS (/crap chat)"),
        "",
        "==== ERKANNTE REKRUTIERUNGEN (neueste oben) ====",
    }
    if #log == 0 then
        lines[1] = "Noch keine Rekrutierungsnachricht erkannt."
        lines[2] = ""
        lines[3] = "Das Addon liest Handel, Allgemein, Suche nach Gruppe, Sagen, Schreien und Flüstern mit"
        lines[4] = "(nicht in Instanzen). Gelesene Nachrichten in dieser Sitzung: " .. (ns.chatSeen or 0)
    end
    for _, l in ipairs(log) do
        lines[#lines + 1] = string.format("[%s] [%s] %s -> %s", date("%d.%m. %H:%M", l.t), l.ch or "?",
            ns.SplitName(l.from), l.guild and ("<" .. l.guild .. ">") or "(Gilde unbekannt)")
        lines[#lines + 1] = "    " .. l.text
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "==== NICHT als Rekrutierung erkannt (enthalten aber Gilde/guild/<...>) ===="
    lines[#lines + 1] = "Steht hier eine echte Gildenwerbung? Dann den Text an den Entwickler schicken,"
    lines[#lines + 1] = "oder mit /crap test <Text> pruefen, warum sie nicht erkannt wurde."
    for _, l in ipairs(ns.db.nearmiss or {}) do
        lines[#lines + 1] = string.format("[%s] %s: %s", date("%d.%m. %H:%M", l.t), ns.SplitName(l.from), l.text)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "==== ROH: die letzten 40 Chat-Nachrichten, die beim Addon ankamen ===="
    for _, l in ipairs(ns.rawlog or {}) do
        lines[#lines + 1] = string.format("[%s] [%s] %s: %s", date("%H:%M:%S", l.t),
            (l.ch and l.ch ~= "" and l.ch) or l.ev:gsub("CHAT_MSG_", ""), ns.SplitName(l.from), l.text)
    end
    self:ShowExport("Chat-Log - erkannte Rekrutierungen (neueste oben)", table.concat(lines, "\n"))
end

function UI:ShowExport(titleText, bodyText)
    if not self.exportFrame then
        local f = ns.T.Window("CBASExport")
        f:SetSize(700, 420)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        tinsert(UISpecialFrames, "CBASExport")
        local t = type(f.TitleText) == "table" and f.TitleText or nil
        if not t then
            t = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            t:SetPoint("TOP", 0, -5)
        end
        f.title = t
        local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 14, -32)
        sf:SetPoint("BOTTOMRIGHT", -32, 14)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false)
        eb:SetFontObject("ChatFontNormal")
        eb:SetWidth(640)
        eb:SetScript("OnEscapePressed", function() f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        self.exportFrame = f
    end
    local f = self.exportFrame
    if bodyText then
        f.title:SetText(titleText or "")
        f.eb:SetText(bodyText)
        f:Show()
        return
    end
    f.title:SetText("Export - Strg+A, Strg+C, dann z.B. in Excel einfügen")
    local lines = { "Gilde;Leistung;Lootsystem;LootSicherheit;Realm;Fraktion;Sprache;Laender;EchteGroesse;Gesehen;AufMaxLevel;Gildenmeister;WhoOnlineMax;GildenfinderMitglieder;RekrutiertZuletzt;Posts;Loot;Raidtage;Zeiten;Fokus;Sucht;Wertung;Favorit;Blacklist;Notiz" }
    self:BuildList()
    for _, e in ipairs(self.list) do
        local g = e.g
        local tags, wanted = {}, {}
        for t in pairs(g.tags) do tags[#tags + 1] = t end
        for w in pairs(g.wanted) do wanted[#wanted + 1] = ROLE_NAMES[w] or ClassName(w) end
        table.sort(tags); table.sort(wanted)
        lines[#lines + 1] = table.concat({
            csv(g.name), (ns.PerformanceScore and ns.PerformanceScore(g)) or "",
            csv((ns.LootShort and ns.LootShort(g)) or ""), csv(select(2, ns.LootShort(g)) or ""),
            csv(g.realm), csv(g.faction), csv(g.lang), csv(ns.CountryList(g)),
            g.inspect and g.inspect.members or "", g.memberCount, e.atMax,
            csv(g.leader and ns.SplitName(g.leader) or ""), g.whoMaxOnline or "",
            g.finder and g.finder.members or "", g.recruit.last and date("%Y-%m-%d", g.recruit.last) or "",
            g.recruit.posts or 0, csv(ns.LootString(g)), csv(g.days), csv(g.times),
            csv(table.concat(tags, ",")), csv(table.concat(wanted, ",")), g.rating or 0,
            g.favorite and "x" or "", g.blacklist and "x" or "", csv(g.notes),
        }, ";")
    end
    -- Zweiter Block: alle gesehenen Spieler
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Gilde;Spieler;Level;Klasse;Rang;Spezialisierung;Itemlevel;PvPTitel;ZuletztGesehen;Ort"
    for _, e in ipairs(self.list) do
        local g = e.g
        for full, m in pairs(g.members) do
            lines[#lines + 1] = table.concat({
                csv(g.name), csv(full), m.level or "", csv(m.class and ClassName(m.class) or ""),
                csv(m.rank or ""), csv(m.spec or ""), m.ilvl or "", csv(m.pvp or ""),
                m.seen and date("%Y-%m-%d", m.seen) or "", csv(m.zone or ""),
            }, ";")
        end
    end
    f.eb:SetText(table.concat(lines, "\n"))
    f:Show()
    f.eb:SetFocus()
    f.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Slash-Befehle
---------------------------------------------------------------------------
local function onoff(v) return v and "|cff40ff40an|r" or "|cffff4040aus|r" end

local SETTING_NAMES = {
    chat = { "chatScan", "Chat-Erkennung" },
    newmsg = { "notifyNew", "Meldung bei jeder neuen Gilde" },
    recruitmsg = { "notifyRecruit", "Meldung bei rekrutierender Gilde" },
    tooltip = { "tooltip", "Tooltip-Info" },
    plates = { "nameplates", "Namensplaketten scannen" },
    sync = { "sync", "Datenaustausch in der Gruppe" },
    dungeons = { "zoneScanDungeons", "Instanz-Scan auch für Dungeons" },
    staedte = { "scanCapitals", "60er-Scan auch in Hauptstädten" },
    inspect = { "inspect", "Inspektion (echte Gildengröße, Itemlevel)" },
}

SLASH_CBAS1 = "/crap"
SLASH_CBAS2 = "/cbas"
SLASH_CBAS3 = "/craphunt"
SLASH_CBAS4 = "/gscout"
SlashCmdList["CBAS"] = function(msg)
    msg = msg or ""
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" or cmd == "show" then
        UI:Toggle()
    elseif cmd == "groesse" or cmd == "größe" or cmd == "size" then
        local pct = tonumber(rest)
        ns.Suite:Create()
        if pct then
            ns.Suite:SetFrameScale(pct / 100)
            ns.Print(string.format("Fenstergröße: %d%%", math.floor(ns.Suite.frame:GetScale() * 100 + 0.5)))
        else
            ns.Print("Benutzung: /crap groesse 120  (60 bis 200 Prozent)")
        end
    elseif cmd == "layer" then
        local L = ns.Layer
        ns.Print("Welt: " .. L.World() .. " · " .. (L.cur and ("Layer " .. (L.Label(L.cur)) .. " in " .. L.cur.zone .. " (ID " .. L.cur.key .. ")")
            or "Layer unbekannt - einen NPC anvisieren"))
        for _, x in ipairs(L:PeerLines()) do print("  " .. x) end
    elseif cmd == "partner" then
        local sub, name = rest:match("^(%S*)%s*(.-)$")
        sub = (sub or ""):lower()
        if sub == "add" and name ~= "" then ns.Layer.AddPartner(name)
        elseif (sub == "del" or sub == "remove") and name ~= "" then ns.Layer.RemovePartner(name)
        else
            ns.Print("Layer-Partner: /crap partner add <Name>  ·  /crap partner del <Name>")
            for _, x in ipairs(ns.Layer:PeerLines()) do print("  " .. x) end
        end
    elseif cmd == "reset" then
        ns.Suite:Create()
        ns.Suite:ResetPosition()
    elseif cmd == "lage" or cmd == "home" or cmd == "start" then
        ns.Suite:Toggle("home")
    elseif cmd == "settings" or cmd == "einstellungen" or cmd == "optionen" then
        ns.Suite:Toggle("settings")
    elseif cmd == "gscout" or cmd == "gilden" then
        ns.Suite:Toggle("gscout")
    elseif cmd == "flip" or cmd == "flipper" then
        local sub, arg = rest:match("^(%S*)%s*(.-)$")
        if (sub or ""):lower() == "add" and arg:find("|Hitem:", 1, true) then
            for link in arg:gmatch("|c%x+|Hitem:.-|h.-|h|r") do ns.Flip.Add(link) end
        elseif (sub or ""):lower() == "next" or (sub or ""):lower() == "step" then
            ns.Flip.Step()
        elseif (sub or ""):lower() == "post" then
            ns.Flip.Mail.Start(arg == "alle")
        elseif (sub or ""):lower() == "budget" then
            local g = tonumber(arg)
            if g then
                ns.Flip.db().settings.maxSpend = math.floor(g * 10000)
                ns.Print(g > 0 and ("Flipper: Budget pro Gegenstand " .. g .. "g.") or "Flipper: kein Budget.")
                if ns.Flip.Refresh then ns.Flip.Refresh() end
            else
                ns.Print("Benutzung: /crap flip budget 500   (Gold pro Gegenstand, 0 = kein Limit)")
            end
        elseif (sub or ""):lower() == "event" or (sub or ""):lower() == "ereignis" then
            local F = ns.Flip
            local evs = F.Events()
            local dd, mm, yy, name = arg:match("^(%d+)%.(%d+)%.?(%d*)%s*(.*)$")
            local del = arg:match("^del%s+(%d+)") or arg:match("^weg%s+(%d+)")
            if dd then
                yy = tonumber(yy) or tonumber(date("%Y"))
                if yy < 100 then yy = yy + 2000 end
                local day = F.DayOfDate(tonumber(dd), tonumber(mm), yy)
                if name == "" then name = "Raidstart" end
                evs[#evs + 1] = { day = day, name = name }
                table.sort(evs, function(a, b) return a.day < b.day end)
                ns.Print(string.format("Flipper: Ereignis \"%s\" am %02d.%02d.%d gespeichert. Erscheint im Verlauf als lila Linie.", name, dd, mm, yy))
            elseif del and evs[tonumber(del)] then
                ns.Print("Flipper: Ereignis \"" .. table.remove(evs, tonumber(del)).name .. "\" entfernt.")
            else
                ns.Print("Ereignisse (Raidstart, neue Phase ...): /crap flip event 10.12.2026 BWL-Start · /crap flip event del <Nr>")
                for i, ev in ipairs(evs) do ns.Print(string.format("  %d. %s - %s", i, date("%d.%m.%Y", F.DayDate(ev.day)), ev.name)) end
            end
        elseif (sub or ""):lower() == "ignore" and arg == "reset" then
            ns.Flip.db().ignore = {}
            ns.Print("Flipper: alle ausgeblendeten Gegenstände sind wieder sichtbar.")
        elseif (sub or ""):lower() == "pilot" or (sub or ""):lower() == "auto" then
            ns.Flip.Pilot()
        elseif (sub or ""):lower() == "snipe" or (sub or ""):lower() == "sniper" then
            ns.Flip.Snipe.Toggle((arg == "an" or arg == "on") and true or ((arg == "aus" or arg == "off") and false or nil))
        elseif (sub or ""):lower() == "reset" then
            local map = { so = 1, mo = 2, di = 3, mi = 4, ["do"] = 5, fr = 6, sa = 7 }
            local k = map[(arg or ""):lower():sub(1, 2)]
            if k then
                ns.Flip.db().settings.resetDay = k
                ns.Print("Flipper: Raid-Reset ist jetzt " .. ns.Flip.WDNAMES[k] .. ".")
            else
                ns.Print("Benutzung: /crap flip reset mi   (Wochentag des Raid-Resets, Standard Mittwoch)")
            end
        elseif (sub or ""):lower() == "find" then
            ns.Suite:Toggle("flipper")
            local U = ns.Flip.UI
            if U and U.frame and U.SetView then U:SetView("kaufen", true) end
            ns.Flip.FindVendorFlips()
            if U and U.Build then U:Build() end
        else
            ns.Suite:Toggle("flipper")
        end
    elseif cmd == "minimap" or cmd == "mm" then
        ns.Standards.SetMinimap(ns.db.settings.minimapHide and true or false)
        ns.Print("Minimap-Knopf: " .. (ns.db.settings.minimapHide and "aus" or "an"))
    elseif cmd == "cihi" or cmd == "canihaveit" or cmd == "fragen" then
        ns.Suite:Toggle("cihi")
    elseif cmd == "land" or cmd == "flagge" or cmd == "country" then
        ns.ChatFlags.Slash(rest)
    elseif cmd == "version" or cmd == "update" then
        ns.Version.Slash()
    elseif cmd == "mem" or cmd == "speicher" then
        ns.MemoryReport()
    elseif cmd == "kurve" or cmd == "leistung" then
        ns.Suite:Toggle("gscout")
        ns.GuildChart.Toggle()
    elseif cmd == "gildenlos" or cmd == "suchende" then
        ns.Suite:Toggle("gildenlos")
    elseif cmd == "geier" or cmd == "geierwacht" or cmd == "loot" then
        ns.Suite:Toggle("geier")
    elseif cmd == "check" and rest ~= "" then
        -- /crap check <Klasse> <Gegenstand>
        local clsName, link = rest:match("^(%S+)%s+(.+)$")
        local file
        if clsName then
            local up = clsName:upper()
            for f, loc in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
                if loc:lower() == clsName:lower() or f == up then file = f end
            end
            for f, loc in pairs(LOCALIZED_CLASS_NAMES_FEMALE or {}) do
                if loc:lower() == clsName:lower() then file = f end
            end
        end
        if not file or not link then
            ns.Print("Benutzung: /crap check <Klasse> <Gegenstand verlinken>  (z.B. /crap check Krieger [Robe])")
        else
            local v, reason = ns.Geier.Evaluate(link, file, ns.MaxLevel())
            if v == "pending" then
                ns.Print("Gegenstandsdaten werden geladen - bitte gleich nochmal versuchen.")
            else
                ns.Print(string.format("%s für %s: %s - %s", link, ns.Geier.ClassName(file),
                    ns.Geier.VERDICT_TEXT[v] or v, reason or ""))
            end
        end
    elseif cmd == "liste" or cmd == "listscan" then
        ns.Suite:Toggle("gscout")
        UI:ListScanStep()
    elseif cmd == "tracker" or cmd == "todo" then
        ns.Suite:Toggle("tracker")
    elseif cmd == "mage" or cmd == "magier" then
        ns.Suite:Toggle("mage")
    elseif cmd == "scan" then
        ns.SmartScanStep()
    elseif cmd == "raidscan" then
        ns.WhoZoneStep()
    elseif cmd == "zonescan" or cmd == "60" then
        ns.WhoZone60Step()
    elseif cmd == "stadt" or cmd == "städte" or cmd == "cities" then
        ns.WhoCapitalStep()
    elseif cmd == "who" and rest ~= "" then
        local g, key = ns.GetGuild(rest, nil, true, "manual")
        ns.WhoGuild(key)
    elseif cmd == "resolve" then
        ns.ResolveNextPending()
    elseif cmd == "export" then
        UI:Create()
        UI:ShowExport()
    elseif cmd == "test" and rest ~= "" then
        local clean = ns.CleanText(rest)
        local ok, why = ns.IsRecruit(clean:lower())
        ns.Print((ok and "|cff40ff40ERKANNT|r" or "|cffff4040NICHT erkannt|r") .. " - " .. (why or ""))
        if ok then
            local n = ns.ExtractGuildName(clean)
            ns.Print("Gildenname: " .. (n and ("<" .. n .. ">") or "keiner erkannt (wird über den Absender zugeordnet)"))
        end
    elseif cmd == "finder" then
        if C_ClubFinder and C_ClubFinder.RequestClubsList then
            local ok = pcall(C_ClubFinder.RequestClubsList, true, rest or "", {})
            ns.Print(ok and "Gildenfinder-Suche gestartet - Ergebnisse werden automatisch übernommen."
                or "Gildenfinder-Suche wurde vom Spiel abgelehnt. Öffne den Gildenfinder einmal selbst (Gilden-Fenster).")
        else
            ns.Print("Diese Spielversion hat keinen Gildenfinder.")
        end
    elseif cmd == "log" then
        UI:Create()
        UI:ShowChatLog()
    elseif cmd == "purge" then
        local days = tonumber(rest) or 60
        ns.Purge(days)
    elseif cmd == "debug" then
        ns.debug = not ns.debug
        ns.Print("Debug " .. onoff(ns.debug))
    elseif SETTING_NAMES[cmd] then
        local s = SETTING_NAMES[cmd]
        ns.db.settings[s[1]] = not ns.db.settings[s[1]]
        ns.Print(s[2] .. ": " .. onoff(ns.db.settings[s[1]]))
    else
        ns.Print("Befehle:")
        print("  /crap - Fenster öffnen/schließen")
        print("  /crap gscout - Reiter GScout öffnen")
        print("  /crap gildenlos - Reiter Gildenlos (gildenlose Spieler, Gildensucher) öffnen")
        print("  /crap geier - Reiter Geierwacht (Loot-Kontrolle) öffnen")
        print("  /crap cihi - Can I have it (Offspec fair bekommen) · /crap minimap - Minimap-Knopf an/aus")
        print("  /crap land DE - dein Land für die Chat-Flaggen (an/aus: /crap land an|aus)")
        print("  /crap version - Version + Download-Link · /crap mem - Speicherverbrauch · /crap kurve - Leistungskurve")
        print("  /crap flip - Reiter Flipper · /crap flip add [Gegenstand] · /crap flip find (analysieren) · budget <Gold> · next (nächster Schritt, für Makros) · post · event TT.MM.JJJJ Name · reset mi · snipe")
        print("  /crap check <Klasse> <Gegenstand> - prüfen, ob ein Gegenstand zur Klasse passt")
        print("  /crap settings - Einstellungen öffnen")
        print("  /crap layer - zeigt deinen Layer, die Welt und deine Layer-Partner")
        print("  /crap partner add|del <Name> - Layer-Partner verwalten (müssen in der Freundesliste sein)")
        print("  /crap reset - Fenster zurück in die Mitte und auf Originalgröße")
        print("  /crap groesse <60-200> - Fenstergröße in Prozent")
        print("  /crap scan - nächster Who-Scan-Schritt")
        print("  /crap raidscan - nächster Instanz-Scan (wer ist gerade in MC, BWL, Strat, Todesminen ...)")
        print("  /crap 60 - nächster 60er-Gebiets-Scan (Silithus, Winterquell ...)")
        print("  /crap stadt - nächster Hauptstadt-Scan (60er in Orgrimmar, Sturmwind ...)")
        print("  /crap who <Gildenname> - Gilde per /who prüfen")
        print("  /crap resolve - Rekrutierer ohne Gildennamen auflösen")
        print("  /crap export - CSV-Export (Gilden + alle Spieler)")
        print("  /crap log - erkannte Rekrutierungen im Chat anzeigen")
        print("  /crap debug - jede erkannte Chat-Nachricht im Chat melden")
        print("  /crap test <Text> - prüfen, ob ein Text als Rekrutierung erkannt wird")
        print("  /crap finder [Text] - Gildenfinder durchsuchen (falls vorhanden)")
        print("  /crap purge [Tage] - alte, unmarkierte Gilden löschen (Standard 60)")
        for k, s in pairs(SETTING_NAMES) do
            print(string.format("  /crap %s - %s (%s)", k, s[2], onoff(ns.db.settings[s[1]])))
        end
    end
end

function CBAS_OnCompartmentClick(_, buttonName, menuFrame)
    if buttonName == "RightButton" and ns.Standards and ns.Standards.ShowMenu then
        ns.Standards.ShowMenu(menuFrame or UIParent)
        return
    end
    UI:Toggle()
end

-- Als Modul in der Suite anmelden (GScout zuerst, dann Einstellungen)
ns.Suite:RegisterModule({
    id = "gscout",
    name = "GScout",
    subName = "Gilden",
    create = function(p) UI:Create(p) end,
    onShow = function() UI:Refresh() end,
})
