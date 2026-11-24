-- CBAS - Layer: auf welchem Layer bin ich? + Abgleich mit Layer-Partnern
-- Erkennung ueber die GUID von NPCs: "Creature-0-<Server>-<Instanz>-<ZonenID>-<NPC>-<Spawn>".
-- Server und ZonenID unterscheiden sich je Layer (gleiche Zone vorausgesetzt).
local ADDON, ns = ...
local S = ns.S

local L = { peers = {} }
ns.Layer = L

local PREFIX = "GScoutL"
local SEND_EVERY = 90         -- Sekunden zwischen Status-Meldungen an Partner
local PEER_TIMEOUT = 15 * 60  -- so lange gilt eine Partner-Meldung

local function split(s, sep)
    local t = {}
    for part in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = part end
    return t
end

function L.World()
    return (GetRealmName and S(GetRealmName())) or "?"
end

local function db()
    ns.db.layerIds = ns.db.layerIds or {}
    return ns.db.layerIds
end

-- Nummer eines Layers innerhalb einer Zone (nach ID sortiert, wie bei Layer-Addons ueblich)
function L.Number(zone, key)
    local ids = db()[zone]
    if not ids or not ids[key] then return nil end
    local list = {}
    for k in pairs(ids) do list[#list + 1] = k end
    table.sort(list, function(a, b)
        local sa, za = a:match("^(%d+)%-(%d+)$")
        local sb, zb = b:match("^(%d+)%-(%d+)$")
        za, zb = tonumber(za) or 0, tonumber(zb) or 0
        if za ~= zb then return za < zb end
        return (tonumber(sa) or 0) < (tonumber(sb) or 0)
    end)
    for i, k in ipairs(list) do if k == key then return i, #list end end
end

function L.Label(info)
    if not info then return "unbekannt" end
    local n, total = L.Number(info.zone, info.key)
    return string.format("#%s", n or "?") .. (total and total > 1 and ("/" .. total) or ""), n
end

-- NPC gesehen -> Layer bestimmen
function L:Seen(unit)
    if not ns.db then return end
    if IsInInstance() then return end
    if not UnitExists(unit) or S(UnitIsPlayer(unit)) then return end
    local guid = S(UnitGUID(unit))
    if type(guid) ~= "string" then return end
    local utype, _, server, _, zoneUID = strsplit("-", guid)
    if (utype ~= "Creature" and utype ~= "Vehicle") or not server or not zoneUID then return end
    local zone = S(GetRealZoneText and GetRealZoneText()) or "?"
    local key = server .. "-" .. zoneUID
    local ids = db()
    ids[zone] = ids[zone] or {}
    ids[zone][key] = time()
    local cur = self.cur
    if not cur or cur.key ~= key or cur.zone ~= zone then
        local old = cur
        self.cur = { key = key, zone = zone, server = server, zid = zoneUID, t = time() }
        if old and old.zone == zone and old.key ~= key then
            ns.Print(string.format("Layer gewechselt: %s -> %s (%s)", L.Label(old), L.Label(self.cur), zone))
        end
        self:SendAll(true)
        self:Changed()
    else
        cur.t = time()
    end
end

function L:Changed()
    if ns.Suite and ns.Suite.UpdateHeader then ns.Suite:UpdateHeader() end
    ns.RefreshUI()
end

-- Zonenwechsel: Layer muss neu erkannt werden
function L:ZoneChanged()
    local zone = S(GetRealZoneText and GetRealZoneText())
    if self.cur and self.cur.zone ~= zone then
        self.lastZoneLayer = self.cur
        self.cur = nil
        self:Changed()
    end
end

---------------------------------------------------------------------------
-- Layer-Partner (per unsichtbarem Fluestern, funktioniert ueber Layer hinweg)
---------------------------------------------------------------------------
function L.Partners()
    ns.db.settings.layerPartners = ns.db.settings.layerPartners or {}
    return ns.db.settings.layerPartners
end

local function FriendOnline(full)
    if not (C_FriendList and C_FriendList.GetFriendInfo) then return nil end
    local name = ns.SplitName(full)
    for _, n in ipairs({ full, name }) do
        local ok, info = pcall(C_FriendList.GetFriendInfo, n)
        if ok and type(info) == "table" then return S(info.connected) and true or false end
    end
    return nil   -- nicht in der Freundesliste
end

function L:Payload()
    local c = self.cur
    local n = c and L.Number(c.zone, c.key)
    return table.concat({ "S", L.World(), c and c.zone or "", c and c.key or "", n or "", time() }, "\031")
end

local function SendTo(target, msg)
    local ok, res = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", target)
    return ok and (res == nil or res == true or res == 0)
end

-- force: sofort (z.B. Layerwechsel), sonst hoechstens alle SEND_EVERY Sekunden
function L:SendAll(force)
    if not ns.db or not C_ChatInfo or not C_ChatInfo.SendAddonMessage then return end
    if InCombatLockdown() then return end
    local now = GetTime()
    if not force and self.lastSend and now - self.lastSend < SEND_EVERY then return end
    self.lastSend = now
    local msg = self:Payload()
    local sent, done = 0, {}
    -- eigene Partner + alle, die sich in letzter Zeit bei mir gemeldet haben
    local targets = {}
    for _, full in ipairs(L.Partners()) do targets[#targets + 1] = full end
    for full, p in pairs(self.peers) do
        if time() - p.t < PEER_TIMEOUT then targets[#targets + 1] = full end
    end
    for _, full in ipairs(targets) do
        if not done[full] then
            done[full] = true
            local online = FriendOnline(full)
            local p = self.peers[full]
            -- nur an Freunde, die online sind (oder die sich gerade selbst gemeldet haben)
            if online or (online == nil and p and time() - p.t < PEER_TIMEOUT) then
                if SendTo(full, msg) then sent = sent + 1 end
            end
        end
    end
    return sent
end

function L:OnMessage(prefix, text, channel, sender)
    if prefix ~= PREFIX then return end
    text, sender = S(text), S(sender)
    if not text or not sender then return end
    sender = ns.NormFull(sender:find("-", 1, true) and sender or ns.FullName(sender))
    if sender == ns.playerFull then return end
    local f = split(text, "\031")
    if f[1] ~= "S" and f[1] ~= "Q" then return end
    local isNew = not self.peers[sender]
    if f[1] == "Q" then
        -- Anfrage: Absender als Partner merken (Layer kennen wir noch nicht)
        local p = self.peers[sender] or { world = f[2], zone = "", key = "" }
        p.t = time()
        self.peers[sender] = p
    end
    if f[1] == "S" then
        self.peers[sender] = { world = f[2], zone = f[3], key = f[4], num = tonumber(f[5]), t = time() }
        -- fremde Layer-IDs fuer die Nummerierung mitlernen
        if f[3] ~= "" and f[4] ~= "" then
            local ids = db()
            ids[f[3]] = ids[f[3]] or {}
            ids[f[3]][f[4]] = ids[f[3]][f[4]] or time()
        end
    end
    -- antworten, damit beide Seiten Bescheid wissen
    if isNew or f[1] == "Q" then SendTo(sender, self:Payload()) end
    if isNew then ns.Print("Layer-Partner " .. ns.SplitName(sender) .. " meldet sich.") end
    self:Changed()
end

-- Partner gleiche Welt + Zone + Layer wie ich?
function L.SameAsMe(p)
    local c = L.cur
    if not c or not p or p.world ~= L.World() then return false end
    return p.zone == c.zone and p.key == c.key
end

function L:PeerLines()
    local out = {}
    local now = time()
    for _, full in ipairs(L.Partners()) do
        local p = self.peers[full]
        local name = ns.SplitName(full)
        if p and now - p.t < PEER_TIMEOUT then
            local same = L.SameAsMe(p)
            local lbl = (p.zone ~= "" and L.Number(p.zone, p.key)) and ("#" .. L.Number(p.zone, p.key)) or "?"
            local where = p.zone ~= "" and (lbl .. " in " .. p.zone) or "Layer noch unbekannt"
            if p.world ~= L.World() then where = where .. " |cff888888(andere Welt: " .. p.world .. ")|r" end
            out[#out + 1] = string.format("%s%s|r: %s%s", same and "|cffff4040" or "|cff40ff40", name, where,
                same and " |cffff4040- GLEICHER LAYER wie du!|r" or "")
        else
            local online = FriendOnline(full)
            out[#out + 1] = "|cff888888" .. name .. ": " ..
                (online == nil and "nicht in deiner Freundesliste" or (online and "online, noch keine Meldung (hat CBAS?)" or "offline")) .. "|r"
        end
    end
    -- wer sich meldet, aber nicht in meiner Liste steht
    for full, p in pairs(self.peers) do
        local listed = false
        for _, x in ipairs(L.Partners()) do if x == full then listed = true end end
        if not listed and now - p.t < PEER_TIMEOUT then
            out[#out + 1] = "|cffaaaaaa" .. ns.SplitName(full) .. " (hat dich als Partner): " ..
                (p.zone ~= "" and (p.zone) or "?") .. (L.SameAsMe(p) and " |cffff4040- GLEICHER LAYER|r" or "") .. "|r"
        end
    end
    return out
end

-- kurze Kopfzeile fuers Fenster
function L:HeaderText()
    local c = self.cur
    local s
    if c then
        s = string.format("Layer |cffffd100%s|r · %s", (L.Label(c)), c.zone)
    elseif IsInInstance() then
        s = "Layer: |cff888888in Instanz|r"
    else
        s = "Layer: |cff888888NPC anvisieren|r"
    end
    local same = 0
    for full, p in pairs(self.peers) do
        if time() - p.t < PEER_TIMEOUT and L.SameAsMe(p) then same = same + 1 end
    end
    if same > 0 then s = s .. " · |cffff4040" .. same .. " Partner gleicher Layer!|r" end
    return s
end

function L.AddPartner(name)
    if not name or name == "" then return end
    local full = ns.NormFull(name:find("-", 1, true) and name or ns.FullName(name))
    for _, x in ipairs(L.Partners()) do if x == full then return end end
    table.insert(L.Partners(), full)
    ns.Print("Layer-Partner hinzugefügt: " .. full .. (FriendOnline(full) == nil and " |cffffd100(bitte auch in die Freundesliste aufnehmen)|r" or ""))
    -- nur anfragen, wenn er sicher online ist (sonst meldet WoW "Spieler nicht gefunden")
    if FriendOnline(full) then SendTo(full, table.concat({ "Q", L.World(), "", "", "", time() }, "\031")) end
    L:Changed()
end

function L.RemovePartner(name)
    local full = ns.NormFull(name:find("-", 1, true) and name or ns.FullName(name))
    for i, x in ipairs(L.Partners()) do
        if x == full or ns.SplitName(x):lower() == name:lower() then
            table.remove(L.Partners(), i)
            L.peers[x] = nil
            ns.Print("Layer-Partner entfernt: " .. x)
            L:Changed()
            return
        end
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
        end
        for _, e in ipairs({ "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED", "NAME_PLATE_UNIT_ADDED",
            "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "CHAT_MSG_ADDON" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        if C_Timer.NewTicker then
            C_Timer.NewTicker(30, function() pcall(L.SendAll, L, false) end)
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        pcall(L.Seen, L, "mouseover")
    elseif event == "PLAYER_TARGET_CHANGED" then
        pcall(L.Seen, L, "target")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not InCombatLockdown() then pcall(L.Seen, L, arg1) end
    elseif event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        pcall(L.ZoneChanged, L)
    elseif event == "CHAT_MSG_ADDON" then
        pcall(L.OnMessage, L, arg1, ...)
    end
end)
