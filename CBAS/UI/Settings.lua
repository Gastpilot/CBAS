-- CBAS - Einstellungen: eine Seite mit Bereichen (links waehlen, rechts einstellen)
-- Jede Option ist ein Schalter mit kurzer Erklaerung. Bereiche:
--   Allgemein · GScout · Geierwacht · Flipper · Chat & Flaggen · Layer · Daten
local ADDON, ns = ...
local Settings = {}
ns.Settings = Settings

local CW = 630          -- Breite der Inhaltsspalte
local CX = 196          -- linker Rand der Inhaltsspalte
local TOPY = -36        -- erste Zeile

local function S() return ns.db.settings end
local unpack = unpack or table.unpack

-- Bereiche und ihre Eintraege
--   { section = "..." }                     Abschnitt
--   { key = "...", label, desc }             Schalter fuer ns.db.settings[key]
--   { get = fn, set = fn(v), label, desc }   Schalter mit eigener Logik
--   { build = fn(page, y) -> y }             freier Block
local CATS = {
    {
        id = "general", name = "Allgemein",
        { section = "Fenster" },
        { build = function(page, y) return Settings.WindowBlock(page, y) end },
        { label = "Minimap-Knopf anzeigen", desc = "Das Einhorn am Kartenrand: Linksklick öffnet CBAS, Rechtsklick zeigt das Schnellmenü.",
          get = function() return not S().minimapHide end,
          set = function(v) if ns.Standards then ns.Standards.SetMinimap(v) end end },
        { section = "Version" },
        { build = function(page, y) return Settings.VersionBlock(page, y) end },
    },
    {
        id = "gscout", name = "GScout",
        { section = "Datensammlung" },
        { key = "chatScan", label = "Chat nach Gildenwerbung durchsuchen", desc = "Erkennt Rekrutierungs-Nachrichten und legt die Gilde samt Loot-System und Raidtagen an." },
        { key = "nameplates", label = "Namensplaketten mitlesen", desc = "Gilden von Spielern um dich herum werden nebenbei gespeichert." },
        { key = "inspect", label = "Gildenmitglieder beim Anvisieren inspizieren", desc = "Liefert echte Gildengröße und Itemlevel. Passiert nur, wenn du jemanden anvisierst." },
        { key = "zoneScanDungeons", label = "Instanz-Scan auch für Dungeons", desc = "Sonst prüft der Instanz-Scan nur Raids." },
        { key = "scanCapitals", label = "60er-Scan auch in Hauptstädten", desc = "Nach den Endgame-Gebieten kommen die sechs Hauptstädte dran." },
        { section = "Austausch" },
        { key = "sync", label = "Daten mit anderen CBAS-Nutzern teilen", desc = "In der Gruppe tauscht CBAS still Gilden-Infos aus. Nichts landet im Chat." },
        { section = "Anzeige & Meldungen" },
        { key = "tooltip", label = "Gildeninfo im Spieler-Tooltip", desc = "Leistung, Loot-System und Notizen beim Überfahren eines Spielers." },
        { key = "notifyRecruit", label = "Meldung bei neuer rekrutierender Gilde", desc = "Eine Zeile im Chatfenster, nur für dich sichtbar." },
        { key = "notifyNew", label = "Meldung bei jeder neuen Gilde", desc = "Kann in Hauptstädten viel werden." },
        { key = "notifySeeker", label = "Meldung, wenn jemand eine Gilde sucht", desc = "Erkennt „suche Gilde“ & Co. im Chat." },
    },
    {
        id = "geier", name = "Geierwacht",
        { section = "Loot-Kontrolle" },
        { key = "lootWatch", label = "Bedarf-Würfe und Beute prüfen", desc = "Vergleicht jeden Bedarf-Wurf in Gruppe und Raid mit Klasse und Spec." },
        { key = "lootAlerts", label = "Warnung bei unpassendem Bedarf-Wurf", desc = "Eine Zeile im Chatfenster, nur für dich sichtbar." },
        { key = "lootSpecInspect", label = "Gruppenmitglieder inspizieren", desc = "Die aktive Spezialisierung gilt als Mainspec. Passiert still im Hintergrund." },
        { key = "lootMSOS", label = "Regel MS > OS", desc = "Mainspec-Bedarf auf Offspec-Beute gilt als fragwürdig." },
        { section = "Can I have it" },
        { label = "Popup beim Würfelfenster", desc = "Zeigt neben dem Würfelfenster, ob du Bedarf würfeln darfst – mit Begründung zum Einfügen.",
          get = function() local c = S().cihi return not c or c.popup ~= false end,
          set = function(v) S().cihi = S().cihi or {}; S().cihi.popup = v end },
    },
    {
        id = "flipper", name = "Flipper",
        { section = "Auktionshaus" },
        { key = "flipTooltip", label = "Flip-Info im Gegenstands-Tooltip", desc = "AH- und Händler-Gewinn direkt beim Überfahren eines Gegenstands." },
        { key = "flipAHHelp", label = "Kaufhilfe neben dem Auktionshaus", desc = "Menge, Kosten und erwarteter Gewinn neben dem Kauf-Fenster." },
        { section = "Händler" },
        { key = "flipAutoVendor", label = "Markierte Händler-Flips automatisch verkaufen", desc = "Beim Händler werden nur Sachen verkauft, die du im Flipper markiert hast." },
    },
    {
        id = "chat", name = "Chat & Flaggen",
        { section = "Chat" },
        { build = function(page, y) return ns.ChatFlags and ns.ChatFlags.BuildSettings(page, y, CW) or y end },
    },
    {
        id = "layer", name = "Layer",
        { section = "Meldungen" },
        { key = "layerChat", label = "Layerwechsel im Chat melden", desc = "Standard: aus. Der aktuelle Layer steht ohnehin oben in der Kopfzeile." },
        { section = "Layer-Partner" },
        { build = function(page, y) return Settings.PartnerBlock(page, y) end },
    },
    {
        id = "data", name = "Daten",
        { section = "Datenbank" },
        { build = function(page, y) return Settings.DataBlock(page, y) end },
    },
}
Settings.CATS = CATS

---------------------------------------------------------------------------
-- freie Bloecke
---------------------------------------------------------------------------
function Settings.WindowBlock(page, y)
    local T, Suite = ns.T, ns.Suite
    local p = Settings.panel
    local lbl = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lbl:SetPoint("TOPLEFT", 0, y - 4)
    lbl:SetText("Größe")
    local minus = T.Button(page, "–", 26, 22)
    minus:SetPoint("TOPLEFT", 120, y)
    minus:SetScript("OnClick", function() Suite:SetFrameScale((Suite.frame:GetScale() or 1) - 0.1) end)
    local size = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    size:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    size:SetWidth(46)
    p.sizeLbl = size
    local plus = T.Button(page, "+", 26, 22)
    plus:SetPoint("LEFT", size, "RIGHT", 8, 0)
    plus:SetScript("OnClick", function() Suite:SetFrameScale((Suite.frame:GetScale() or 1) + 0.1) end)
    local reset = T.Button(page, "Position & Größe zurücksetzen", 210, 22, "quiet")
    reset:SetPoint("LEFT", plus, "RIGHT", 16, 0)
    reset:SetScript("OnClick", function() Suite:ResetPosition() end)
    local d = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", 0, y - 28)
    d:SetWidth(CW)
    d:SetJustifyH("LEFT")
    d:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    d:SetText("Verschieben: an jeder freien Stelle ziehen  ·  Größe: auch mit dem Griff unten rechts (Rechtsklick = 100 %)")
    return y - 54
end

function Settings.VersionBlock(page, y)
    if not ns.Version then return y end
    ns.Version.BuildSettings(page)
    local box = page.versionBox
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", 0, y)
    box:SetSize(CW, 104)
    return y - 116
end

function Settings.PartnerBlock(page, y)
    local T = ns.T
    local p = Settings.panel
    local d = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", 0, y)
    d:SetWidth(CW)
    d:SetJustifyH("LEFT")
    d:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    d:SetText("Freunde mit CBAS, mit denen ihr euch gegenseitig den Layer zeigt. Namen mit Komma trennen, dann Enter. Sie müssen in deiner Freundesliste stehen.")
    local pe = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    pe:SetSize(CW - 10, 22)
    pe:SetPoint("TOPLEFT", 6, y - 34)
    pe:SetAutoFocus(false)
    pe:SetScript("OnEscapePressed", pe.ClearFocus)
    pe:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local list = {}
        for part in (self:GetText() or ""):gmatch("[^,]+") do
            local n = part:gsub("^%s+", ""):gsub("%s+$", "")
            if n ~= "" then list[#list + 1] = n end
        end
        ns.db.settings.layerPartners = {}
        for _, n in ipairs(list) do ns.Layer.AddPartner(n) end
    end)
    p.partnerEdit = pe
    return y - 66
end

function Settings.DataBlock(page, y)
    local T = ns.T
    local p = Settings.panel
    local stats = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stats:SetPoint("TOPLEFT", 0, y)
    stats:SetWidth(CW)
    stats:SetJustifyH("LEFT")
    stats:SetSpacing(3)
    p.stats = stats
    local purge = T.Button(page, "Alte Gilden aufräumen (60 Tage)", 230, 24)
    purge:SetPoint("TOPLEFT", 0, y - 54)
    purge:SetScript("OnClick", function() ns.Purge(60); Settings.Show(p) end)
    local exp = T.Button(page, "Export", 90, 24, "quiet")
    exp:SetPoint("LEFT", purge, "RIGHT", 10, 0)
    exp:SetScript("OnClick", function() if ns.UI and ns.UI.ShowExport then ns.UI:ShowExport() end end)
    local mem = T.Button(page, "Speicher prüfen", 130, 24, "quiet")
    mem:SetPoint("LEFT", exp, "RIGHT", 6, 0)
    mem:SetScript("OnClick", function() if SlashCmdList and SlashCmdList.CBAS then SlashCmdList.CBAS("mem") end end)
    local d = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    d:SetPoint("TOPLEFT", 0, y - 88)
    d:SetWidth(CW)
    d:SetJustifyH("LEFT")
    d:SetTextColor(T.C.dim[1], T.C.dim[2], T.C.dim[3])
    d:SetText("Aufräumen löscht Gilden und Gildenlose, die seit 60 Tagen weder gesehen noch beim Werben erwischt wurden. Favoriten, Blacklist, bewertete Gilden und alles mit Notiz bleibt.\n„Speicher prüfen“ schreibt den Speicherverbrauch der Module ins Chatfenster (nur für dich).")
    return y - 130
end

---------------------------------------------------------------------------
-- Aufbau
---------------------------------------------------------------------------
local function BuildPage(p, cat)
    local T = ns.T
    local page = CreateFrame("Frame", nil, p)
    page:SetPoint("TOPLEFT", CX, 0)
    page:SetSize(CW, 540)
    page:Hide()
    local y = TOPY
    for _, it in ipairs(cat) do
        if it.section then
            if y < TOPY then y = y - 10 end
            local h = T.Section(page, it.section, CW)
            h:SetPoint("TOPLEFT", 0, y)
            y = y - 24
        elseif it.build then
            y = it.build(page, y)
        else
            local cb = T.Toggle(page, it.label, it.desc, function(c)
                local v = c:GetChecked() and true or false
                if it.key then ns.db.settings[it.key] = v elseif it.set then it.set(v) end
                ns.RefreshUI()
            end, CW)
            cb:SetPoint("TOPLEFT", 0, y)
            cb.key, cb.get = it.key, it.get
            table.insert(p.checks, cb)
            y = y - cb.rowHeight
        end
    end
    return page
end

function Settings.SelectCat(id)
    local p = Settings.panel
    if not p or not p.pages[id] then id = "general" end
    for cid, page in pairs(p.pages) do page:SetShown(cid == id) end
    for cid, b in pairs(p.catBtns) do if cid == id then b:LockHighlight() else b:UnlockHighlight() end end
    p.cat = id
    if ns.db then ns.db.settings.lastSettingsCat = id end
end

function Settings.Create(p)
    local T = ns.T
    Settings.panel = p
    p.checks, p.pages, p.catBtns = {}, {}, {}
    -- Bereichsliste links mit feiner Trennlinie
    local sep = p:CreateTexture(nil, "BORDER")
    sep:SetTexture(T.WHITE)
    sep:SetVertexColor(unpack(T.C.line))
    sep:SetWidth(1)
    sep:SetPoint("TOPLEFT", CX - 18, TOPY)
    sep:SetPoint("BOTTOMLEFT", CX - 18, 14)
    local y = TOPY
    for _, cat in ipairs(CATS) do
        local b = ns.Suite.NavItem(p, cat.name, nil, true)
        b:SetWidth(CX - 40)
        b:SetPoint("TOPLEFT", 14, y)
        b:SetScript("OnClick", function() Settings.SelectCat(cat.id) end)
        p.catBtns[cat.id] = b
        y = y - 26
        p.pages[cat.id] = BuildPage(p, cat)
    end
    Settings.SelectCat(ns.db and ns.db.settings.lastSettingsCat or "general")
end

local function UpdateSizeLabel(p)
    if p and p.sizeLbl and ns.Suite.frame then
        p.sizeLbl:SetText(string.format("%d %%", math.floor((ns.Suite.frame:GetScale() or 1) * 100 + 0.5)))
    end
end
function ns.Suite:OnScaleChanged() UpdateSizeLabel(Settings.panel) end

function Settings.Show(p)
    p = p or Settings.panel
    if not p then return end
    UpdateSizeLabel(p)
    if ns.Version then ns.Version.UpdateSettings() end
    if ns.ChatFlags then ns.ChatFlags.UpdateSettings() end
    if p.partnerEdit and not p.partnerEdit:HasFocus() then
        local names = {}
        for _, f in ipairs((ns.Layer and ns.Layer.Partners()) or {}) do names[#names + 1] = ns.SplitName(f) end
        p.partnerEdit:SetText(table.concat(names, ", "))
    end
    for _, cb in ipairs(p.checks) do
        if cb.key then cb:SetChecked(ns.db.settings[cb.key] and true or false)
        elseif cb.get then cb:SetChecked(cb.get() and true or false) end
    end
    if p.stats then
        local g, m = 0, 0
        for _, gg in pairs(ns.db.guilds) do
            g = g + 1
            m = m + (gg.memberCount or 0)
        end
        p.stats:SetText(string.format("%d Gilden  ·  %d Spieler\n|cff8f949fRegion %s  ·  Server %s|r",
            g, m, ns.region or "?", tostring(ns.MyRealm())))
    end
end
