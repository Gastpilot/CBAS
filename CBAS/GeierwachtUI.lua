-- CBAS - Geierwacht: Reiter-Oberflaeche
local ADDON, ns = ...
local GW = ns.Geier
local GUI = {}
GW.UI = GUI

local ROWS, ROW_H = 18, 20
local HCOLS = {
    { label = "Zeit", w = 42 },
    { label = "Spieler", w = 105, align = "LEFT" },
    { label = "Wurf", w = 62 },
    { label = "Gegenstand", w = 150, align = "LEFT" },
    { label = "Urteil", w = 145, align = "LEFT" },
}
local PROWS = 10

local function Btn(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    return b
end

local function Check(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    local fs = (type(cb.Text) == "table" and cb.Text) or nil
    if not fs then
        fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    fs:SetFontObject("GameFontHighlightSmall")
    fs:SetText(label)
    return cb
end

local function Box(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0, 0, 0, 0.5)
        f:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end
end

function GUI:Create(p)
    self.frame = p
    self.offset, self.poffset = 0, 0

    -- Filter
    self.cbSusp = Check(p, "Nur fragwürdig/Geier")
    self.cbSusp:SetPoint("TOPLEFT", 14, -32)
    self.cbNeed = Check(p, "Nur Bedarf & Beute")
    self.cbNeed:SetPoint("LEFT", self.cbSusp, "RIGHT", 118, 0)
    self.cbNeed:SetChecked(true)
    for _, cb in ipairs({ self.cbSusp, self.cbNeed }) do
        cb:SetScript("OnClick", function() GUI.offset = 0; GUI:Refresh() end)
    end
    local sl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sl:SetPoint("LEFT", self.cbNeed, "RIGHT", 108, 0)
    sl:SetText("Spieler:")
    local search = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    search:SetSize(90, 20)
    search:SetPoint("LEFT", sl, "RIGHT", 8, 0)
    search:SetAutoFocus(false)
    search:SetScript("OnTextChanged", function() GUI.offset = 0; GUI:Refresh() end)
    search:SetScript("OnEscapePressed", search.ClearFocus)
    search:SetScript("OnEnterPressed", search.ClearFocus)
    self.search = search

    -- Run-Auswahl (oben rechts) + Blaettern
    local runBtn = Btn(p, "Run: alle", 250)
    runBtn:SetPoint("TOPRIGHT", -40, -31)
    runBtn:SetScript("OnClick", function() GUI:ToggleRunMenu() end)
    self.runBtn = runBtn
    local prev = Btn(p, "<", 24)
    prev:SetPoint("RIGHT", runBtn, "LEFT", -2, 0)
    prev:SetScript("OnClick", function() GUI:StepRun(1) end)
    local nxt = Btn(p, ">", 24)
    nxt:SetPoint("LEFT", runBtn, "RIGHT", 2, 0)
    nxt:SetScript("OnClick", function() GUI:StepRun(-1) end)

    -- Kopfzeile Verlauf
    local x = 16
    for _, c in ipairs(HCOLS) do
        local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h:SetPoint("TOPLEFT", x, -62)
        h:SetSize(c.w, 18)
        h:SetJustifyH(c.align or "CENTER")
        h:SetText(c.label)
        x = x + c.w + 2
    end
    local listW = x - 16

    local area = CreateFrame("Frame", nil, p)
    area:SetPoint("TOPLEFT", 14, -82)
    area:SetSize(listW + 4, ROWS * ROW_H)
    area:EnableMouseWheel(true)
    area:SetScript("OnMouseWheel", function(_, d)
        GUI.offset = math.max(0, math.min(math.max(0, #GUI.list - ROWS), GUI.offset - d * 3))
        GUI:UpdateRows()
    end)
    self.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, area)
        r:SetSize(listW, ROW_H)
        r:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        if i % 2 == 0 then
            local bg = r:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end
        r.cells = {}
        local cx = 0
        for ci, c in ipairs(HCOLS) do
            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 2, 0)
            fs:SetSize(c.w - 4, ROW_H)
            fs:SetJustifyH(c.align or "CENTER")
            fs:SetWordWrap(false)
            r.cells[ci] = fs
            cx = cx + c.w + 2
        end
        r:SetScript("OnEnter", function(self)
            local h = self.entry
            if not h then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if h.link then pcall(GameTooltip.SetHyperlink, GameTooltip, h.link) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Geierwacht: " .. (GW.VERDICT_TEXT[h.verdict or "info"] or ""), 1, 1, 1)
            if h.reason and h.reason ~= "" then GameTooltip:AddLine(h.reason, 1, 0.82, 0, true) end
            if h.itemRoles and next(h.itemRoles) then
                GameTooltip:AddLine("Gegenstand für: " .. GW.RoleList(h.itemRoles), 0.8, 0.8, 1, true)
            end
            local main, msrc, offs = GW.PlayerRoles(h.player, h.class)
            local offN = {}
            for _, o in ipairs(offs) do offN[#offN + 1] = GW.ROLE_NAMES[o] end
            GameTooltip:AddLine(string.format("Spieler: Main %s%s · Off %s",
                main and GW.ROLE_NAMES[main] or "unbekannt", msrc and (" (" .. msrc .. ")") or "",
                #offN > 0 and table.concat(offN, ", ") or "unbekannt"), 0.8, 0.8, 1, true)
            local fit = GW.RoleFit(h.itemRoles, h.player, h.class)
            local FIT = { main = "|cff40ff40passt zum Mainspec|r", off = "|cffffd100passt zum Offspec|r",
                possible = "|cffffd100passt zu einer möglichen Rolle der Klasse|r", none = "|cffff4040passt zu keiner Rolle der Klasse|r" }
            if fit then GameTooltip:AddLine(FIT[fit], 1, 1, 1) end
            GameTooltip:AddLine(string.format("%s %s · %s%s", GW.ClassName(h.class or "?"), h.level or "?",
                date("%d.%m. %H:%M", h.t), h.zone and (" · " .. h.zone) or ""), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        r:SetScript("OnClick", function(self)
            if self.entry then
                GUI.selected = self.entry.player
                GUI:Refresh()
            end
        end)
        self.rows[i] = r
    end

    -- Rechte Seite: Spielerliste
    local side = CreateFrame("Frame", nil, p, "BackdropTemplate")
    side:SetPoint("TOPLEFT", 540, -58)
    side:SetPoint("BOTTOMRIGHT", -12, 42)
    Box(side)
    local st = side:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    st:SetPoint("TOPLEFT", 10, -8)
    st:SetText("Spieler (nach Geier-Wert)")
    self.sideTitle = st
    local ph = side:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("TOPLEFT", 10, -26)
    ph:SetText("Name                         Bedarf  frag.  Geier")
    self.prows = {}
    for i = 1, PROWS do
        local r = CreateFrame("Button", nil, side)
        r:SetSize(285, 18)
        r:SetPoint("TOPLEFT", 8, -40 - (i - 1) * 18)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.2, 0.6, 1, 0.25)
        sel:Hide()
        r.sel = sel
        local a = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        a:SetPoint("LEFT", 2, 0)
        a:SetSize(150, 18)
        a:SetJustifyH("LEFT")
        a:SetWordWrap(false)
        local b = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b:SetPoint("LEFT", 152, 0)
        b:SetSize(130, 18)
        b:SetJustifyH("LEFT")
        r.a, r.b = a, b
        r:SetScript("OnClick", function(self)
            if self.full then GUI.selected = self.full; GUI:Refresh() end
        end)
        self.prows[i] = r
    end
    side:EnableMouseWheel(true)
    side:SetScript("OnMouseWheel", function(_, d)
        GUI.poffset = math.max(0, math.min(math.max(0, #(GUI.plist or {}) - PROWS), GUI.poffset - d))
        GUI:UpdatePlayers()
    end)

    -- Details zum gewaehlten Spieler
    local det = side:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    det:SetPoint("TOPLEFT", 10, -226)
    det:SetPoint("TOPRIGHT", -10, -226)
    det:SetJustifyH("LEFT")
    det:SetJustifyV("TOP")
    det:SetSpacing(2)
    self.det = det

    local nl = side:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nl:SetPoint("TOPLEFT", 10, -348)
    nl:SetText("Notiz zur Markierung:")
    local note = CreateFrame("EditBox", nil, side, "InputBoxTemplate")
    note:SetSize(265, 20)
    note:SetPoint("TOPLEFT", 16, -362)
    note:SetAutoFocus(false)
    note:SetScript("OnEscapePressed", note.ClearFocus)
    note:SetScript("OnEnterPressed", note.ClearFocus)
    note:SetScript("OnTextChanged", function(self, user)
        local m = user and GUI.selected and GW.db().marked[GUI.selected]
        if m then m.note = self:GetText() end
    end)
    self.note = note

    local mark = Btn(side, "Als Geier markieren", 140)
    mark:SetPoint("TOPLEFT", 8, -388)
    mark:SetScript("OnClick", function()
        if not GUI.selected then return end
        local d = GW.db()
        GW.Mark(GUI.selected, not d.marked[GUI.selected], GUI.note:GetText())
    end)
    self.markBtn = mark

    local report = Btn(side, "In Gruppe melden", 140)
    report:SetPoint("LEFT", mark, "RIGHT", 4, 0)
    report:SetScript("OnClick", function() GUI:Report() end)
    self.reportBtn = report
    report:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Schreibt eine kurze Info zum gewählten Spieler in den Gruppen-/Raidchat.\n(In Instanzen sperrt WoW Forever das für Addons.)", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    report:SetScript("OnLeave", GameTooltip_Hide)

    local forget = Btn(side, "Spieler-Werte zurücksetzen", 284)
    forget:SetPoint("TOPLEFT", mark, "BOTTOMLEFT", 0, -4)
    forget:SetScript("OnClick", function()
        if GUI.selected then
            GW.db().players[GUI.selected] = nil
            GUI:Refresh()
        end
    end)

    -- Untere Leiste
    local clear = Btn(p, "Verlauf leeren", 110)
    clear:SetPoint("BOTTOMLEFT", 14, 12)
    clear:SetScript("OnClick", function()
        wipe(GW.db().history)
        wipe(GW.db().runs)
        GUI.runId = nil
        GUI.offset = 0
        GUI:Refresh()
    end)
    local status = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    status:SetPoint("LEFT", clear, "RIGHT", 12, 0)
    status:SetJustifyH("LEFT")
    self.status = status
    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 16, -450)
    hint:SetWidth(515)
    hint:SetJustifyH("LEFT")
    self.hint = hint
    self.hintDefault = ("Geprüft wird: Rüstungsart, Waffenart, Schild/Buchband/Götze/Totem, \"Klassen:\"-Beschränkung und Werte.\nTest ohne Gruppe: /crap check <Klasse> <Gegenstand verlinken>")
    hint:SetText(self.hintDefault)

    p:SetScript("OnShow", function() GUI:Refresh() end)
    -- Sperre "In Gruppe melden" herunterzaehlen
    local acc = 0
    p:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 0.1 then return end
        acc = 0
        GUI:UpdateReportButton()
    end)
    GW.Refresh = function()
        if GUI.frame and GUI.frame:IsVisible() and not GUI.queued then
            GUI.queued = true
            C_Timer.After(0.3, function() GUI.queued = false; GUI:Refresh() end)
        end
    end
end

function GUI:BuildList()
    local d = GW.db()
    local onlySusp = self.cbSusp:GetChecked()
    local onlyNeed = self.cbNeed:GetChecked()
    local q = (self.search:GetText() or ""):lower()
    local list = {}
    local runId = self.runId
    for _, h in ipairs(d.history) do
        local ok = true
        if runId and h.run ~= runId then ok = false end
        if ok and onlySusp and h.verdict ~= "frag" and h.verdict ~= "geier" then ok = false end
        if ok and onlyNeed and not (h.kind == "need" or h.kind == "offneed" or ((h.kind == "got" or h.kind == "won") and h.verdict ~= "info")) then ok = false end
        if ok and q ~= "" and not h.player:lower():find(q, 1, true) then ok = false end
        if ok then list[#list + 1] = h end
    end
    self.list = list

    local pl = {}
    if runId then
        -- nur Spieler dieses Runs, mit Werten aus diesem Run
        local run = GW.RunById(runId)
        local stats = {}
        for full, cls in pairs(run and run.members or {}) do
            stats[full] = { class = type(cls) == "string" and cls or (d.players[full] and d.players[full].class), needs = 0, frag = 0, geier = 0 }
        end
        for _, h in ipairs(d.history) do
            if h.run == runId then
                local s = stats[h.player] or { class = h.class, needs = 0, frag = 0, geier = 0 }
                stats[h.player] = s
                s.class = s.class or h.class
                if h.kind == "need" or h.kind == "offneed" then s.needs = s.needs + 1 end
                if h.verdict == "frag" then s.frag = s.frag + 1 end
                if h.verdict == "geier" then s.geier = s.geier + 1 end
            end
        end
        for full, s in pairs(stats) do
            pl[#pl + 1] = { full = full, p = s, score = s.geier * 2 + s.frag + (d.marked[full] and 100 or 0) }
        end
    else
        for full, pp in pairs(d.players) do
            local _, lvl = GW.PlayerLabel(pp)
            pl[#pl + 1] = { full = full, p = pp, score = (pp.geier or 0) * 2 + (pp.frag or 0) + (d.marked[full] and 100 or 0) + lvl }
        end
        for full in pairs(d.marked) do
            if not d.players[full] then pl[#pl + 1] = { full = full, p = {}, score = 100 } end
        end
    end
    table.sort(pl, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.full < b.full
    end)
    self.plist = pl
end

function GUI:UpdateRows()
    for i = 1, ROWS do
        local r = self.rows[i]
        local h = self.list[self.offset + i]
        r.entry = h
        if h then
            local name = ns.SplitName(h.player)
            r.cells[1]:SetText(date("%H:%M", h.t))
            r.cells[2]:SetText(GW.ClassColor(h.class or "") .. name .. "|r")
            local roll = GW.ROLL_TEXT[h.kind] or h.kind
            if h.roll then roll = roll .. " " .. h.roll end
            if h.won then roll = "|cffffd100" .. roll .. "|r |TInterface\\RaidFrame\\ReadyCheck-Ready:12|t" end
            r.cells[3]:SetText(roll)
            r.cells[4]:SetText(h.link or "?")
            local v = GW.VERDICT_TEXT[h.verdict or "info"] or ""
            local fit = GW.RoleFit(h.itemRoles, h.player, h.class)
            if fit == "main" then v = v .. " |cff40ff40Main|r"
            elseif fit == "off" then v = v .. " |cffffd100Off|r"
            elseif fit == "none" then v = v .. " |cffff4040keine Rolle|r" end
            if h.verdict == "frag" or h.verdict == "geier" then v = v .. " |cffcccccc" .. (h.reason or "") .. "|r" end
            r.cells[5]:SetText(v)
            r:Show()
        else
            r:Hide()
        end
    end
end

function GUI:UpdatePlayers()
    local d = GW.db()
    for i = 1, PROWS do
        local r = self.prows[i]
        local e = self.plist[self.poffset + i]
        if e then
            r.full = e.full
            local name = ns.SplitName(e.full)
            local mark = d.marked[e.full] and "|cffff4040[G] |r" or ""
            local main, _, offs = GW.PlayerRoles(e.full, e.p.class)
            local rt = ""
            if main or #offs > 0 then
                local parts = { main and ("|cff40ff40" .. GW.ROLE_SHORT[main] .. "|r") or "?" }
                for _, o in ipairs(offs) do parts[#parts + 1] = "|cffffd100" .. GW.ROLE_SHORT[o] .. "|r" end
                rt = " |cff888888[|r" .. table.concat(parts, "|cff888888/|r") .. "|cff888888]|r"
            end
            r.a:SetText(mark .. GW.ClassColor(e.p.class or "") .. name .. "|r" .. rt)
            r.b:SetText(string.format("%5d  %5d  %5d", e.p.needs or 0, e.p.frag or 0, e.p.geier or 0))
            if self.selected == e.full then r.sel:Show() else r.sel:Hide() end
            r:Show()
        else
            r.full = nil
            r:Hide()
        end
    end
end

function GUI:UpdateDetail()
    local d = GW.db()
    local full = self.selected
    if not full then
        self.det:SetText("|cff888888Spieler auswählen (links oder oben).|r")
        self.markBtn:SetEnabled(false)
        self:UpdateReportButton()
        return
    end
    self.markBtn:SetEnabled(true)
    local p = d.players[full] or {}
    local m = d.marked[full]
    local label = GW.PlayerLabel(p)
    local runInfo
    if self.runId then
        for _, e in ipairs(self.plist or {}) do
            if e.full == full then runInfo = e.p end
        end
    end
    local L = {}
    L[#L + 1] = GW.ClassColor(p.class or "") .. full .. "|r  " .. label .. (m and "  |cffff4040[markiert]|r" or "")
    L[#L + 1] = string.format("%s, Level %s", GW.ClassName(p.class or "?"), p.level or "?")
    local main, msrc, offs, osrc, others = GW.PlayerRoles(full, p.class)
    L[#L + 1] = "|cff40ff40Mainspec:|r " .. (main and GW.ROLE_NAMES[main] or "unbekannt") ..
        (msrc and (" |cff888888(" .. msrc .. ")|r") or "")
    local offN = {}
    for _, o in ipairs(offs) do offN[#offN + 1] = GW.ROLE_NAMES[o] end
    local othN = {}
    for _, o in ipairs(others) do othN[#othN + 1] = GW.ROLE_NAMES[o] end
    L[#L + 1] = "|cffffd100Offspec:|r " .. (#offN > 0 and (table.concat(offN, ", ") .. " |cff888888(" .. osrc .. ")|r")
        or ("|cff888888unbekannt" .. (#othN > 0 and (" - möglich: " .. table.concat(othN, ", ")) or "") .. "|r"))
    if p.groupRole and p.groupRole ~= "NONE" then
        local GR = { TANK = "Tank", HEALER = "Heiler", DAMAGER = "Schaden" }
        L[#L + 1] = "|cff888888Gruppenrolle: " .. (GR[p.groupRole] or p.groupRole) .. "|r"
    end
    L[#L + 1] = string.format("Gesamt: %d Bedarf · %d fragwürdig · %d Geier", p.needs or 0, p.frag or 0, p.geier or 0)
    if runInfo then
        L[#L + 1] = string.format("|cffffd100In diesem Run:|r %d Bedarf · %d fragwürdig · %d Geier",
            runInfo.needs or 0, runInfo.frag or 0, runInfo.geier or 0)
    end
    -- in wie vielen Runs war der Spieler dabei?
    local nRuns = 0
    for _, r in ipairs(d.runs or {}) do if r.members and r.members[full] then nRuns = nRuns + 1 end end
    if nRuns > 0 then L[#L + 1] = "|cff888888Mit dir in " .. nRuns .. " Run(s) gewesen|r" end
    -- Gilde aus GScout
    local key = ns.db.players[full]
    if key and ns.db.guilds[key] then L[#L + 1] = "Gilde: <" .. ns.db.guilds[key].name .. ">" end
    -- die letzten unpassenden Wuerfe
    local n = 0
    for _, h in ipairs(d.history) do
        if h.player == full and (h.verdict == "frag" or h.verdict == "geier") then
            n = n + 1
            if n <= 3 then L[#L + 1] = "|cff888888" .. date("%d.%m.", h.t) .. "|r " .. (h.link or "?") .. " " .. (GW.VERDICT_TEXT[h.verdict] or "") end
        end
    end
    self.det:SetText(table.concat(L, "\n"))
    self.markBtn:SetText(m and "Markierung entfernen" or "Als Geier markieren")
    self:UpdateReportButton()
    if not self.note:HasFocus() then self.note:SetText(m and m.note or "") end
end

function GUI:RunSummary(r)
    local dur = (r.stop or r.last or r.start) - r.start
    local parts = {
        string.format("|cffffd100%s|r%s", r.zone or "?", r.difficulty and r.difficulty ~= "" and (" (" .. r.difficulty .. ")") or ""),
        date("%d.%m. %H:%M", r.start) .. (r.stop and ("-" .. date("%H:%M", r.stop)) or " |cff40ff40läuft|r"),
        string.format("%d Min.", math.floor(dur / 60)),
        string.format("%d Spieler", r.size or 0),
        string.format("%d Bedarf-Würfe", r.rolls or 0),
        string.format("%s%d auffällig|r", (r.susp or 0) > 0 and "|cffff4040" or "|cff40ff40", r.susp or 0),
    }
    if r.lootMethod then parts[#parts + 1] = r.lootMethod end
    if r.leader then parts[#parts + 1] = "Leiter: " .. ns.SplitName(r.leader) end
    local s = table.concat(parts, " · ")
    if r.instance and (r.rolls or 0) == 0 then
        s = s .. "\n|cff888888Keine Würfe erfasst - in Instanzen sperrt Forever den Beute-Chat evtl. für Addons.|r"
    end
    return s
end

function GUI:Refresh()
    if not self.frame or not self.frame:IsVisible() then return end
    local run = self.runId and GW.RunById(self.runId)
    if self.runId and not run then self.runId = nil end
    self.runBtn:SetText(run and ("Run: " .. GW.RunTitle(run)) or ("Run: alle (" .. #(GW.db().runs or {}) .. ")"))
    self.sideTitle:SetText(run and "Spieler in diesem Run" or "Spieler (nach Geier-Wert)")
    self.hint:SetText(run and self:RunSummary(run) or self.hintDefault)
    self:BuildList()
    self.offset = math.min(self.offset, math.max(0, #self.list - ROWS))
    self.poffset = math.min(self.poffset, math.max(0, #self.plist - PROWS))
    self:UpdateRows()
    self:UpdatePlayers()
    self:UpdateDetail()
    local d = GW.db()
    local susp, total = 0, 0
    for _, h in ipairs(d.history) do
        if h.kind == "need" or h.kind == "offneed" then total = total + 1 end
        if h.verdict == "frag" or h.verdict == "geier" then susp = susp + 1 end
    end
    self.status:SetText(string.format("%d Bedarf-Würfe erfasst · %d auffällig · Beute-Meldungen gelesen: %d%s",
        total, susp, GW.seen or 0, (GW.secret or 0) > 0 and (" · gesperrt (Instanz): " .. GW.secret) or ""))
end

-- Run waehlen: dir = +1 aelterer, -1 neuerer
function GUI:StepRun(dir)
    local runs = GW.db().runs or {}
    if #runs == 0 then return end
    local idx = 0
    for i, r in ipairs(runs) do if r.id == self.runId then idx = i end end
    idx = idx + dir
    if idx < 1 then self.runId = nil
    elseif idx > #runs then idx = #runs; self.runId = runs[idx].id
    else self.runId = runs[idx].id end
    self.offset = 0
    self:Refresh()
end

function GUI:ToggleRunMenu()
    if self.runMenu and self.runMenu:IsShown() then self.runMenu:Hide() return end
    if not self.runMenu then
        local m = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        m:SetFrameStrata("DIALOG")
        m:SetPoint("TOPRIGHT", self.runBtn, "BOTTOMRIGHT", 0, -2)
        m:SetWidth(330)
        Box(m)
        if m.SetBackdropColor then m:SetBackdropColor(0.05, 0.05, 0.08, 0.95) end
        m.lines = {}
        for i = 1, 21 do
            local b = CreateFrame("Button", nil, m)
            b:SetSize(316, 16)
            b:SetPoint("TOPLEFT", 7, -6 - (i - 1) * 16)
            b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", 4, 0)
            fs:SetSize(310, 16)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            b.fs = fs
            b:SetScript("OnClick", function(self)
                GUI.runId = self.runId
                GUI.offset = 0
                m:Hide()
                GUI:Refresh()
            end)
            m.lines[i] = b
        end
        self.runMenu = m
    end
    local m = self.runMenu
    local runs = GW.db().runs or {}
    local n = 1
    m.lines[1].runId = nil
    m.lines[1].fs:SetText("|cffffd100Alle Runs|r")
    m.lines[1]:Show()
    for i = 1, math.min(20, #runs) do
        local r = runs[i]
        local b = m.lines[i + 1]
        b.runId = r.id
        b.fs:SetText(string.format("%s |cff888888(%d Würfe%s)|r%s", GW.RunTitle(r), r.rolls or 0,
            (r.susp or 0) > 0 and (", |cffff4040" .. r.susp .. " auffällig|r|cff888888") or "",
            r.stop and "" or " |cff40ff40läuft|r"))
        b:Show()
        n = i + 1
    end
    for i = n + 1, #m.lines do m.lines[i]:Hide() end
    m:SetHeight(12 + n * 16)
    m:Show()
end

local REPORT_CD = 10
function GUI:ReportCooldown()
    if not self.lastReport then return 0 end
    return math.max(0, REPORT_CD - (GetTime() - self.lastReport))
end

function GUI:UpdateReportButton()
    local b = self.reportBtn
    if not b then return end
    local rem = self:ReportCooldown()
    if rem > 0 then
        b:SetEnabled(false)
        b:SetText(string.format("Melden |cffffd100%ds|r", math.ceil(rem)))
        self.reportCd = true
    elseif self.reportCd or not b:IsEnabled() then
        self.reportCd = false
        b:SetText("In Gruppe melden")
        b:SetEnabled(self.selected ~= nil)
    end
end

function GUI:Report()
    local full = self.selected
    if not full or self:ReportCooldown() > 0 then return end
    local d = GW.db()
    local p = d.players[full] or {}
    local ch = IsInRaid() and "RAID" or (IsInGroup() and "PARTY") or nil
    if not ch then ns.Print("Du bist in keiner Gruppe.") return end
    local main = GW.PlayerRoles(full, p.class)
    local msg = string.format("[CBAS Geierwacht] %s (%s%s): %d Bedarf-Würfe, davon %d fragwürdig und %d auf unpassende Beute.",
        ns.SplitName(full), GW.ClassName(p.class or "?"), main and (", " .. GW.ROLE_NAMES[main]) or "",
        p.needs or 0, p.frag or 0, p.geier or 0)
    local m = d.marked[full]
    if m and m.note and m.note ~= "" then msg = msg .. " Notiz: " .. m.note end
    local ok = pcall(SendChatMessage, msg:sub(1, 255), ch)
    if not ok then ns.Print("Senden nicht möglich (in Instanzen gesperrt).") end
    self.lastReport = GetTime()
    self:UpdateReportButton()
end

ns.Suite:RegisterModule({
    id = "geier",
    name = "Geierwacht",
    create = function(p) GUI:Create(p) end,
    onShow = function() GUI:Refresh() end,
})
