-- CBAS - "Can I have it": Ansicht in der Geierwacht (Geierwacht | Can I have it)
local ADDON, ns = ...
local GW = ns.Geier
local CI = ns.CanIHave
local UI = {}
CI.UI = UI

local ROWS, ROW_H = 13, 20
local COLS = {
    { label = "Zeit", w = 44 },
    { label = "Gegenstand", w = 200, align = "LEFT" },
    { label = "Für", w = 70 },
    { label = "Bedarf?", w = 150, align = "LEFT" },
    { label = "MS-Bedarf bei", w = 150, align = "LEFT" },
    { label = "Status", w = 170, align = "LEFT" },
}

local function Btn(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
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

-- Rollen-Wahl mit < > (nil = automatisch)
local function Cycler(p, label, x, y, get, set, options)
    local l = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", x, y)
    l:SetText(label)
    local prev = Btn(p, "<", 22)
    prev:SetPoint("LEFT", l, "RIGHT", 6, 0)
    local txt = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    txt:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    txt:SetWidth(84)
    local nxt = Btn(p, ">", 22)
    nxt:SetPoint("LEFT", prev, "RIGHT", 92, 0)
    local function Step(d)
        local opts = options()
        local cur, idx = get(), 1
        for i, o in ipairs(opts) do if o.v == cur then idx = i end end
        idx = (idx + d - 1) % #opts + 1
        set(opts[idx].v)
        UI:Refresh()
    end
    prev:SetScript("OnClick", function() Step(-1) end)
    nxt:SetScript("OnClick", function() Step(1) end)
    return function()
        local cur = get()
        for _, o in ipairs(options()) do if o.v == cur then txt:SetText(o.t) end end
    end
end

function UI:Create(p)
    self.frame = p
    local h = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("TOPLEFT", 16, -34)
    h:SetText("Can I have it? |cffccccccDarf ich Bedarf würfeln? - die Geierwacht-Regeln, auf dich angewendet|r")
    local info = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", 16, -52)
    info:SetPoint("TOPRIGHT", -16, -52)
    info:SetJustifyH("LEFT")
    info:SetText("Bei jedem Würfelfenster prüft CBAS mit denselben Regeln wie die Geierwacht: passt es zu deiner Klasse und einer deiner Specs, " ..
        "braucht es jemand als |cffffd100Mainspec|r (der hat Vorrang)? |cff40ff40BEDARF OK|r = vertretbar, mit fertiger Begründung, falls jemand fragt. " ..
        "CBAS würfelt und schreibt nie selbst.")

    -- Einstellungen
    local s = CI.db()
    local function RoleOpts(withAuto, autoTxt)
        local opts = {}
        if withAuto then opts[1] = { v = nil, t = autoTxt } end
        for _, r in ipairs(GW.CLASS_ROLES[CI.MyClass() or ""] or {}) do opts[#opts + 1] = { v = r, t = GW.ROLE_NAMES[r] } end
        return opts
    end
    self.upd = {}
    self.upd[1] = Cycler(p, "Meine Mainspec:", 16, -86, function() return CI.db().main end,
        function(v) CI.db().main = v end, function() return RoleOpts(true, "automatisch") end)
    self.upd[2] = Cycler(p, "Offspec:", 290, -86, function() return CI.db().off end,
        function(v) CI.db().off = v end, function() return RoleOpts(true, "alle anderen") end)
    self.upd[3] = Cycler(p, "Sprache:", 520, -86, function() return CI.db().lang end,
        function(v) CI.db().lang = v end, function()
            return { { v = "auto", t = "automatisch" }, { v = "de", t = "Deutsch" }, { v = "en", t = "Englisch" } }
        end)
    local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("TOPLEFT", 740, -82)
    local cbt = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbt:SetPoint("LEFT", cb, "RIGHT", 0, 1)
    cbt:SetText("Popup")
    cb:SetScript("OnClick", function(c) CI.db().popup = c:GetChecked() and true or false end)
    Tip(cb, "Bei einer Offspec-Chance erscheint oben ein kleines Fenster mit Rat und Knöpfen.")
    self.cbPopup = cb

    -- Liste
    local x = 0
    local head = CreateFrame("Frame", nil, p)
    head:SetPoint("TOPLEFT", 14, -116)
    head:SetSize(830, 18)
    for _, c in ipairs(COLS) do
        local fs = head:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", x + 2, 0)
        fs:SetWidth(c.w - 4)
        fs:SetJustifyH(c.align or "CENTER")
        fs:SetText(c.label)
        x = x + c.w + 2
    end
    self.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, p)
        r:SetSize(x, ROW_H)
        r:SetPoint("TOPLEFT", 14, -134 - (i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.2, 0.6, 1, 0.3)
        sel:Hide()
        r.sel = sel
        r.cells = {}
        local cx = 0
        for ci, c in ipairs(COLS) do
            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 2, 0)
            fs:SetSize(c.w - 4, ROW_H)
            fs:SetJustifyH(c.align or "CENTER")
            fs:SetWordWrap(false)
            r.cells[ci] = fs
            cx = cx + c.w + 2
        end
        r:SetScript("OnClick", function(row) if row.e then UI.selected = row.e; UI:Refresh() end end)
        r:SetScript("OnEnter", function(row)
            if row.e and row.e.link then
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetHyperlink, GameTooltip, row.e.link)
                GameTooltip:Show()
            end
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        self.rows[i] = r
    end

    local det = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    det:SetPoint("TOPLEFT", 16, -134 - ROWS * ROW_H - 8)
    det:SetPoint("TOPRIGHT", -16, -134 - ROWS * ROW_H - 8)
    det:SetJustifyH("LEFT")
    det:SetJustifyV("TOP")
    det:SetSpacing(2)
    self.det = det

    -- Knoepfe
    local ask = Btn(p, "Begründung posten", 140)
    ask:SetPoint("BOTTOMLEFT", 14, 12)
    ask:SetScript("OnClick", function()
        local e = UI.selected
        if not e then return end
        if e.state == "wait" or e.state == "boe" then CI.Ask(e) else CI.Reason(e) end
    end)
    local wh = Btn(p, "Gewinner fragen", 130)
    wh:SetPoint("LEFT", ask, "RIGHT", 6, 0)
    wh:SetScript("OnClick", function() if UI.selected then CI.WhisperWinner(UI.selected) end end)
    local th = Btn(p, "Danke sagen", 110)
    th:SetPoint("LEFT", wh, "RIGHT", 6, 0)
    th:SetScript("OnClick", function() if UI.selected then CI.Thanks(UI.selected) end end)
    for _, b in ipairs({ ask, wh, th }) do
        Tip(b, "Der Text landet in deiner Chat-Eingabe - ändern und mit Enter selbst abschicken.")
    end
    self.ask, self.wh, self.th = ask, wh, th
    -- Gegenstand selbst pruefen (z.B. aus AtlasLoot oder dem Chat)
    local edit = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    edit:SetSize(220, 20)
    edit:SetPoint("BOTTOMRIGHT", -20, 13)
    edit:SetAutoFocus(false)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", function(e)
        local t = e:GetText()
        e:SetText("")
        e:ClearFocus()
        local link = t and t:match("(|c%x+|Hitem:.-|h.-|h|r)")
        if not link then return end
        local r = CI.Check(link)
        if r.state == "pending" then ns.Print("Can I have it: Gegenstandsdaten laden noch - gleich nochmal.") return end
        ns.Print("Can I have it: " .. link .. " - " .. (CI.STATE_TXT[r.state] or "kein Ausrüstungsteil") .. " " .. (r.why or ""))
    end)
    local el = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    el:SetPoint("BOTTOMRIGHT", edit, "TOPRIGHT", 0, 2)
    el:SetText("Gegenstand prüfen: Shift-Klick hier hinein + Enter")
    Tip(edit, "Prüft einen beliebigen Gegenstand für dich (z.B. aus AtlasLoot oder dem Chat):\npasst er zu deiner Offspec - und dürftest du fragen?")

    p:SetScript("OnShow", function() UI:Refresh() end)
    CI.Refresh = function() if p:IsVisible() then UI:Refresh() end end
end

function UI:Refresh()
    if not self.frame or not self.frame:IsVisible() then return end
    for _, u in ipairs(self.upd) do u() end
    self.cbPopup:SetChecked(CI.db().popup ~= false)
    local _, list = CI.db()
    for i = 1, ROWS do
        local r = self.rows[i]
        local e = list[i]
        r.e = e
        if e then
            local c = r.cells
            c[1]:SetText(date("%H:%M", e.t))
            c[2]:SetText(e.link)
            c[3]:SetText(GW.ROLE_NAMES[e.role or ""] or "-")
            c[4]:SetText(CI.STATE_TXT[e.state] or "")
            c[5]:SetText(e.ms and #e.ms > 0 and table.concat(e.ms, ", ") or "|cff888888niemand|r")
            local st
            if e.mine then st = "|cff40ff40erhalten|r" .. (e.thanked and " · bedankt" or "")
            elseif e.winner then st = (e.canWhisper and "|cffffd100" or "|cff888888") .. "an " .. e.winner .. "|r" .. (e.whispered and " · angefragt" or "")
            elseif e.asked then st = "gefragt " .. date("%H:%M", e.asked)
            else st = "|cff888888offen|r" end
            c[6]:SetText(st)
            r.sel:SetShown(self.selected == e)
            r:Show()
        else
            r:Hide()
        end
    end
    local e = self.selected
    local main, offs = CI.MyRoles()
    local offT = {}
    for _, o in ipairs(offs) do offT[#offT + 1] = GW.ROLE_NAMES[o] end
    local head = string.format("Du: |cffffd100%s|r als Mainspec, Offspec: |cffffd100%s|r · Sprache der Texte: %s",
        GW.ROLE_NAMES[main or ""] or "?", #offT > 0 and table.concat(offT, ", ") or "-", CI.Lang() == "de" and "Deutsch" or "Englisch")
    if e then
        self.det:SetText(head .. "\n" .. e.link .. ": " .. (e.why or ""))
    else
        self.det:SetText(head .. "\n|cff888888Hier erscheint jeder Drop mit Würfelfenster. Zeile anklicken für Begründung und Knöpfe. Unten rechts: beliebigen Gegenstand prüfen.|r")
    end
    local isWait = e and (e.state == "wait" or e.state == "boe")
    self.ask:SetText(isWait and "Höflich fragen" or "Begründung posten")
    self.ask:SetEnabled(e and e.state ~= "no" and not e.mine and true or false)
    self.wh:SetEnabled(e and e.winner and e.canWhisper and not e.mine and true or false)
    self.th:SetEnabled(e and e.mine and true or false)
end

ns.Suite:RegisterModule({
    id = "cihi",
    name = "Can I have it",
    parent = "geier",
    hidden = true,
    create = function(p) UI:Create(p) end,
    onShow = function() UI:Refresh() end,
})
