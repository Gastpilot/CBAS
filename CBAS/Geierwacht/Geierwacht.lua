-- CBAS (Craphunts Blacklisted Addon Suite) - Geierwacht: prueft, ob Loot zur Klasse passt
-- Quellen: Beute-Chat (Bedarf/Gier/gewonnen/erhalten) und - falls vorhanden - der Beuteverlauf (C_LootHistory).
local ADDON, ns = ...
local S = ns.S

local GW = {}
ns.Geier = GW

---------------------------------------------------------------------------
-- Regeln (Classic)
---------------------------------------------------------------------------
-- Rüstung: 1 Stoff, 2 Leder, 3 Schwere Rüstung, 4 Platte, 6 Schild, 7 Buchband, 8 Götze, 9 Totem
local ARMOR_NAMES = { [1] = "Stoff", [2] = "Leder", [3] = "Schwere Rüstung", [4] = "Platte", [6] = "Schild",
    [7] = "Buchband", [8] = "Götze", [9] = "Totem" }
local BEST_ARMOR = { WARRIOR = 4, PALADIN = 4, HUNTER = 3, SHAMAN = 3, ROGUE = 2, DRUID = 2, PRIEST = 1, MAGE = 1, WARLOCK = 1 }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
local RELIC = { [7] = "PALADIN", [8] = "DRUID", [9] = "SHAMAN" }

-- Waffen: 0 Axt 1H, 1 Axt 2H, 2 Bogen, 3 Schusswaffe, 4 Streitkolben 1H, 5 Streitkolben 2H, 6 Stangenwaffe,
-- 7 Schwert 1H, 8 Schwert 2H, 10 Stab, 13 Faustwaffe, 15 Dolch, 16 Wurfwaffe, 18 Armbrust, 19 Zauberstab
local WEAPON_NAMES = { [0] = "Einhandaxt", [1] = "Zweihandaxt", [2] = "Bogen", [3] = "Schusswaffe",
    [4] = "Einhandstreitkolben", [5] = "Zweihandstreitkolben", [6] = "Stangenwaffe", [7] = "Einhandschwert",
    [8] = "Zweihandschwert", [10] = "Stab", [13] = "Faustwaffe", [15] = "Dolch", [16] = "Wurfwaffe",
    [18] = "Armbrust", [19] = "Zauberstab" }
local function set(...) local t = {} for _, v in ipairs({ ... }) do t[v] = true end return t end
local WEAPONS = {
    WARRIOR = set(0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18),
    PALADIN = set(0, 1, 4, 5, 6, 7, 8),
    HUNTER  = set(0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18),
    ROGUE   = set(2, 3, 4, 7, 13, 15, 16, 18),
    PRIEST  = set(4, 10, 15, 19),
    SHAMAN  = set(0, 1, 4, 5, 10, 13, 15),
    MAGE    = set(7, 10, 15, 19),
    WARLOCK = set(7, 10, 15, 19),
    DRUID   = set(4, 5, 10, 13, 15),
}

-- Welche Hauptwerte nuetzen der Klasse?
local STAT_USE = {
    STR   = set("WARRIOR", "PALADIN", "SHAMAN", "DRUID", "ROGUE"),
    AGI   = set("WARRIOR", "HUNTER", "ROGUE", "SHAMAN", "DRUID"),
    INT   = set("PALADIN", "HUNTER", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"),
    SPI   = set("PRIEST", "MAGE", "WARLOCK", "DRUID", "SHAMAN"),
    SPELL = set("PALADIN", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"),
}
local STAT_NAMES = { STR = "Stärke", AGI = "Beweglichkeit", INT = "Intelligenz", SPI = "Willenskraft", SPELL = "Zaubermacht/Heilung" }
local STAT_KEYS = {
    ITEM_MOD_STRENGTH_SHORT = "STR", ITEM_MOD_AGILITY_SHORT = "AGI", ITEM_MOD_INTELLECT_SHORT = "INT",
    ITEM_MOD_SPIRIT_SHORT = "SPI", ITEM_MOD_SPELL_POWER_SHORT = "SPELL", ITEM_MOD_SPELL_HEALING_DONE_SHORT = "SPELL",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "SPELL", ITEM_MOD_STRENGTH = "STR", ITEM_MOD_AGILITY = "AGI",
    ITEM_MOD_INTELLECT = "INT", ITEM_MOD_SPIRIT = "SPI",
}
-- Tooltip-Texte, die auf Zauberwerte hindeuten (Classic: "Erhöht durch Zauber ... verursachten Schaden")
local SPELL_TEXT = { "zauber", "spell", "heilung", "healing", "mana alle 5", "mana per 5", "mana pro 5" }

local function ClassName(file)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file
end
local function ClassColor(file)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    return c and c.colorStr and ("|c" .. c.colorStr) or "|cffffffff"
end
GW.ClassName, GW.ClassColor = ClassName, ClassColor

-- Lokalisierte Klassennamen -> Datei-Name (fuer "Klassen: Priester")
local function ClassFromLocalized(name)
    name = name and name:lower()
    for _, tbl in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for file, loc in pairs(tbl) do
            if loc:lower() == name then return file end
        end
    end
end

---------------------------------------------------------------------------
-- Rollen: TANK, HEAL, CASTER (Zauber-DD), PHYS (Nah-/Fernkampf-DD)
---------------------------------------------------------------------------
local ROLE_NAMES = { TANK = "Tank", HEAL = "Heiler", CASTER = "Zauber-DD", PHYS = "Nahkampf/Fern-DD" }
local ROLE_SHORT = { TANK = "T", HEAL = "H", CASTER = "Z", PHYS = "N" }
GW.ROLE_NAMES, GW.ROLE_SHORT = ROLE_NAMES, ROLE_SHORT
local CLASS_ROLES = {
    WARRIOR = { "TANK", "PHYS" }, PALADIN = { "HEAL", "TANK", "PHYS" }, HUNTER = { "PHYS" },
    ROGUE = { "PHYS" }, PRIEST = { "HEAL", "CASTER" }, SHAMAN = { "HEAL", "CASTER", "PHYS" },
    MAGE = { "CASTER" }, WARLOCK = { "CASTER" }, DRUID = { "HEAL", "TANK", "PHYS", "CASTER" },
}
GW.CLASS_ROLES = CLASS_ROLES
-- Spezialisierungen, die Zauber-DD sind (Rest der DD-Specs = PHYS)
local CASTER_SPECS = { "gleichgewicht", "balance", "elementar", "elemental", "schatten", "shadow", "arkan",
    "arcane", "feuer", "fire", "frost", "gebrechen", "affliction", "dämonologie", "demonology",
    "zerstörung", "destruction" }

-- Spezialisierungs-/Gruppenrolle des Spiels -> unsere Rolle
function GW.MapRole(gameRole, class, specName)
    if gameRole == "TANK" then return "TANK" end
    if gameRole == "HEALER" then return "HEAL" end
    if gameRole == "DAMAGER" then
        local roles = CLASS_ROLES[class] or {}
        local hasC, hasP = false, false
        for _, r in ipairs(roles) do
            if r == "CASTER" then hasC = true elseif r == "PHYS" then hasP = true end
        end
        if hasC and not hasP then return "CASTER" end
        if hasP and not hasC then return "PHYS" end
        if specName then
            local s = specName:lower()
            for _, k in ipairs(CASTER_SPECS) do
                if s:find(k, 1, true) then return "CASTER" end
            end
            return "PHYS"
        end
        return nil   -- DD, aber unklar ob Zauber oder physisch
    end
end

---------------------------------------------------------------------------
-- Gegenstandsdaten
---------------------------------------------------------------------------
local function GetInfo(link)
    local f = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not f then return nil end
    local ok, name, _, quality, ilvl, minLevel, _, _, _, equipLoc, _, _, classID, subclassID, bindType = pcall(f, link)
    if not ok or not name then return nil end
    return { name = name, quality = quality, ilvl = ilvl, minLevel = minLevel, equipLoc = equipLoc,
        classID = classID, subclassID = subclassID, bindType = bindType }
end

local function TooltipLines(link)
    local lines = {}
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)
        if ok and data and data.lines then
            for _, l in ipairs(data.lines) do
                local t = S(l.leftText)
                if type(t) == "string" then lines[#lines + 1] = t end
            end
        end
    end
    return lines
end

local function ItemStats(link, lines)
    local found, raw = {}, {}
    local f = (C_Item and C_Item.GetItemStats) or GetItemStats
    if f then
        local ok, st = pcall(f, link)
        if ok and type(st) == "table" then
            raw = st
            for k in pairs(st) do
                if STAT_KEYS[k] then found[STAT_KEYS[k]] = true end
            end
        end
    end
    -- Zauberwerte stehen in Classic oft nur als "Anlegen:"-Text im Tooltip (Zeile 1 = Name ueberspringen)
    for i, l in ipairs(lines) do
        local low = i > 1 and l:lower() or ""
        for _, w in ipairs(SPELL_TEXT) do
            if low:find(w, 1, true) then found.SPELL = true break end
        end
        -- Fallback fuer Grundwerte im Text ("+12 Intelligenz")
        if low:find("^%+%d+ stärke") or low:find("^%+%d+ strength") then found.STR = true end
        if low:find("^%+%d+ beweglichkeit") or low:find("^%+%d+ agility") then found.AGI = true end
        if low:find("^%+%d+ intelligenz") or low:find("^%+%d+ intellect") then found.INT = true end
        if low:find("^%+%d+ willenskraft") or low:find("^%+%d+ spirit") then found.SPI = true end
    end
    return found, raw
end

local CLASSES_PATTERN
local function AllowedClasses(lines)
    if not CLASSES_PATTERN and type(ITEM_CLASSES_ALLOWED) == "string" then
        CLASSES_PATTERN = "^" .. ITEM_CLASSES_ALLOWED:gsub("%%s", "(.+)") .. "$"
    end
    local pat = CLASSES_PATTERN or "^Klassen: (.+)$"
    for _, l in ipairs(lines) do
        local list = l:match(pat) or l:match("^Classes: (.+)$")
        if list then
            local allowed = {}
            for n in list:gmatch("[^,]+") do
                local file = ClassFromLocalized(n:gsub("^%s+", ""):gsub("%s+$", ""))
                if file then allowed[file] = true end
            end
            if next(allowed) then return allowed end
        end
    end
end

local function IsBoE(info, lines)
    if info.bindType == 2 then return true end
    for _, l in ipairs(lines) do
        if (ITEM_BIND_ON_EQUIP and l == ITEM_BIND_ON_EQUIP) or l:find("Beim Anlegen gebunden", 1, true)
            or l:find("Binds when equipped", 1, true) then return true end
    end
    return false
end

local TANK_KEYS = { ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = true, ITEM_MOD_DODGE_RATING_SHORT = true,
    ITEM_MOD_PARRY_RATING_SHORT = true, ITEM_MOD_BLOCK_RATING_SHORT = true, ITEM_MOD_BLOCK_VALUE_SHORT = true }
local PHYS_KEYS = { ITEM_MOD_ATTACK_POWER_SHORT = true, ITEM_MOD_RANGED_ATTACK_POWER_SHORT = true }
local HEAL_KEYS = { ITEM_MOD_SPELL_HEALING_DONE_SHORT = true, ITEM_MOD_MANA_REGENERATION_SHORT = true }
local CASTER_KEYS = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = true, ITEM_MOD_SPELL_PENETRATION_SHORT = true }

-- Fuer welche Rollen ist der Gegenstand gedacht? (leere Menge = fuer alle/unklar)
function GW.ItemRoles(link, info, lines, rawStats, stats)
    local r = {}
    local function add(x) r[x] = true end
    rawStats = rawStats or {}
    for k in pairs(rawStats) do
        if TANK_KEYS[k] then add("TANK") end
        if PHYS_KEYS[k] then add("PHYS") end
        if HEAL_KEYS[k] then add("HEAL") end
        if CASTER_KEYS[k] then add("CASTER") end
        if k == "ITEM_MOD_SPELL_POWER_SHORT" then add("HEAL"); add("CASTER") end
    end
    for i, l in ipairs(lines or {}) do
        local low = i > 1 and l:lower() or ""   -- Zeile 1 ist der Name
        local spell = low:find("zauber", 1, true) or low:find("spell", 1, true) or low:find("magisch", 1, true)
        if low:find("verteidigung", 1, true) or low:find("defense", 1, true) or low:find("ausweich", 1, true)
            or low:find("dodge", 1, true) or low:find("parier", 1, true) or low:find("parry", 1, true)
            or low:find("blocken", 1, true) or low:find("block", 1, true) then add("TANK") end
        local heal = low:find("heilung", 1, true) or low:find("healing", 1, true) or low:find("mana alle 5", 1, true)
            or low:find("mana per 5", 1, true) or low:find("mana every 5", 1, true)
        local dmg = low:find("schaden", 1, true) or low:find("damage", 1, true)
        if heal then add("HEAL") end
        if spell and dmg then add("CASTER") end
        if spell and not dmg and not heal and (low:find("krit", 1, true) or low:find("trefferchance", 1, true)
            or low:find("critical", 1, true) or low:find(" hit", 1, true)) then add("CASTER"); add("HEAL") end
        if not spell and (low:find("angriffskraft", 1, true) or low:find("attack power", 1, true)
            or low:find("kritischen treffer", 1, true) or low:find("critical strike", 1, true)
            or low:find("trefferchance", 1, true) or low:find("chance to hit", 1, true)) then add("PHYS") end
    end
    stats = stats or {}
    if stats.STR or stats.AGI then add("PHYS") end
    if stats.STR and info and info.classID == 4 and info.subclassID == 4 and not stats.AGI then add("TANK") end
    if (stats.INT or stats.SPI) and not r.HEAL and not r.CASTER then add("HEAL"); add("CASTER") end
    if info then
        if info.classID == 4 and info.subclassID == 6 and not r.HEAL and not r.CASTER then add("TANK") end
        if info.classID == 2 then
            local sub = info.subclassID
            if sub == 19 then add("CASTER"); add("HEAL")
            elseif sub == 2 or sub == 3 or sub == 18 or sub == 16 then add("PHYS")
            elseif not next(r) then add("PHYS") end
        end
    end
    return r
end

local function RoleList(set)
    local t = {}
    for _, k in ipairs({ "TANK", "HEAL", "CASTER", "PHYS" }) do
        if set[k] then t[#t + 1] = ROLE_NAMES[k] end
    end
    return table.concat(t, ", ")
end
GW.RoleList = RoleList

---------------------------------------------------------------------------
-- Pruefung: "ok" | "frag" (fragwuerdig) | "geier" | "info" (nicht pruefbar)
---------------------------------------------------------------------------
function GW.Evaluate(link, class, level)
    local info = GetInfo(link)
    if not info then return "pending", "Gegenstandsdaten werden geladen" end
    if not class or not BEST_ARMOR[class] then return "info", "Klasse unbekannt" end
    level = level or ns.MaxLevel()
    local lines = TooltipLines(link)
    local reasons, verdict, nFrag = {}, "ok", 0
    local function flag(v, r)
        reasons[#reasons + 1] = r
        if v == "frag" then nFrag = nFrag + 1 end
        if v == "geier" or (v == "frag" and verdict == "ok") then verdict = v end
        -- zwei Auffaelligkeiten zusammen (z.B. falsche Ruestung UND falsche Werte) = Geier
        if nFrag >= 2 then verdict = "geier" end
    end

    local isArmor, isWeapon = info.classID == 4, info.classID == 2
    local equippable = info.equipLoc and info.equipLoc ~= "" and info.equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
    if not equippable and not isArmor and not isWeapon then
        return "info", "kein Ausrüstungsgegenstand"
    end

    -- Werte vorab auswerten (beeinflusst die Ruestungs-Pruefung)
    local stats, rawStats = ItemStats(link, lines)
    local usefulStat, anyStat, useless = false, false, {}
    for st in pairs(stats) do
        if STAT_USE[st] then
            anyStat = true
            if STAT_USE[st][class] then usefulStat = true else useless[#useless + 1] = STAT_NAMES[st] end
        end
    end
    local notes = {}

    -- 1) Klassen-Beschraenkung im Tooltip
    local allowed = AllowedClasses(lines)
    if allowed and not allowed[class] then
        local names = {}
        for c in pairs(allowed) do names[#names + 1] = ClassName(c) end
        table.sort(names)
        flag("geier", "nur für " .. table.concat(names, ", "))
    end

    -- 2) Ruestungsart
    if isArmor then
        local sub = info.subclassID
        local loc = info.equipLoc
        if sub == 6 then
            if not SHIELD[class] then flag("geier", ClassName(class) .. " kann keine Schilde tragen") end
        elseif RELIC[sub] then
            if RELIC[sub] ~= class then flag("geier", ARMOR_NAMES[sub] .. " nur für " .. ClassName(RELIC[sub])) end
        elseif sub and sub >= 1 and sub <= 4 and loc ~= "INVTYPE_CLOAK" then
            local best = BEST_ARMOR[class]
            local canWear = sub <= best
            -- Jaeger/Schamanen lernen Schwere Ruestung, Krieger/Paladine Platte erst mit 40
            if sub == 3 and (class == "HUNTER" or class == "SHAMAN") and level < 40 then canWear = false end
            if sub == 4 and level < 40 then canWear = false end
            if sub > best then
                flag("geier", ClassName(class) .. " kann kein(e) " .. ARMOR_NAMES[sub] .. " tragen")
            elseif not canWear then
                flag("frag", ARMOR_NAMES[sub] .. " erst ab Level 40 tragbar")
            elseif sub < best then
                local lowOk = level < 40 and sub == best - 1
                if not lowOk then
                    if usefulStat then
                        -- z.B. Krieger mit Leder+Beweglichkeit: in Classic durchaus ueblich
                        notes[#notes + 1] = ARMOR_NAMES[sub] .. " statt " .. ARMOR_NAMES[best] .. ", Werte passen aber"
                    else
                        flag("frag", ClassName(class) .. " trägt eigentlich " .. ARMOR_NAMES[best] .. ", nicht " .. ARMOR_NAMES[sub])
                    end
                end
            end
        end
    end

    -- 3) Waffenart
    if isWeapon and info.subclassID and WEAPON_NAMES[info.subclassID] then
        local w = WEAPONS[class]
        if w and not w[info.subclassID] then
            flag("geier", ClassName(class) .. " kann keine " .. WEAPON_NAMES[info.subclassID] .. " benutzen")
        end
    end

    -- 4) Werte (oben berechnet)
    if anyStat and not usefulStat then
        table.sort(useless)
        flag("frag", "Werte passen nicht (" .. table.concat(useless, ", ") .. ")")
    end

    -- 5) BoE: wertvoll zum Verkaufen
    local boe = IsBoE(info, lines)
    if boe and verdict ~= "ok" then reasons[#reasons + 1] = "BoE - lässt sich verkaufen!" end

    if verdict == "ok" then
        reasons[#reasons + 1] = "passt zur Klasse"
        for _, n in ipairs(notes) do reasons[#reasons + 1] = n end
    end
    local roles = GW.ItemRoles(link, info, lines, rawStats, stats)
    return verdict, table.concat(reasons, "; "), { boe = boe, quality = info.quality, roles = roles }
end

---------------------------------------------------------------------------
-- Spieler in der Gruppe finden (Klasse, Level)
---------------------------------------------------------------------------
local function GroupUnits()
    local u = { "player" }
    if IsInRaid() then
        for i = 1, (GetNumGroupMembers() or 0) do u[#u + 1] = "raid" .. i end
    else
        for i = 1, 4 do u[#u + 1] = "party" .. i end
    end
    return u
end

GW.GroupUnits = function() return GroupUnits() end

function GW.PlayerInfo(full)
    for _, unit in ipairs(GroupUnits()) do
        if UnitExists(unit) then
            local n, r = UnitName(unit)
            n, r = S(n), S(r)
            if n and ns.NormFull(ns.FullName(n, r)) == full then
                local _, cls = UnitClass(unit)
                local role = UnitGroupRolesAssigned and S(UnitGroupRolesAssigned(unit))
                if role and role ~= "NONE" then
                    local p = GW.db().players[full] or {}
                    GW.db().players[full] = p
                    p.groupRole = role
                    p.class = p.class or S(cls)
                end
                return S(cls), S(UnitLevel(unit)), unit
            end
        end
    end
    -- aus GScout bekannt?
    local key = ns.db.players[full]
    local g = key and ns.db.guilds[key]
    local m = g and g.members[full]
    if m then return m.class, m.level end
    local p = GW.db().players[full]
    if p then return p.class, p.level end
end

---------------------------------------------------------------------------
-- Datenhaltung
---------------------------------------------------------------------------
function GW.db()
    local d = ns.db.loot
    if d and not d.runs then d.runs = {} end
    if not d then
        d = { history = {}, players = {}, marked = {}, runs = {} }
        ns.db.loot = d
    end
    return d
end

-- Main- und Offspec eines Spielers bestimmen
-- Rueckgabe: main (Rolle|nil), mainQuelle, offs (Liste), offQuelle, moegliche (Liste)
function GW.PlayerRoles(full, class)
    local p = GW.db().players[full] or {}
    class = class or p.class
    local possible = CLASS_ROLES[class or ""] or {}
    local main, mainSrc
    -- Spezialisierung aus GScout-Inspektion (Gildenmitglieder) mitnutzen
    if not p.specRole then
        local key = ns.db.players[full]
        local gm = key and ns.db.guilds[key] and ns.db.guilds[key].members[full]
        if gm and gm.role then p = setmetatable({ specRole = gm.role, spec = gm.spec }, { __index = p }) end
    end
    if p.specRole then
        main = GW.MapRole(p.specRole, class, p.spec)
        if main then mainSrc = "Inspektion" .. (p.spec and (": " .. p.spec) or "") end
    end
    if not main and p.groupRole and p.groupRole ~= "NONE" then
        main = GW.MapRole(p.groupRole, class)
        if main then mainSrc = "Gruppenrolle" end
    end
    -- aus den Bedarf-Wuerfen: welche Rollen-Ausruestung wird gesammelt?
    local counts = p.roleCounts or {}
    local order = {}
    for _, r in ipairs(possible) do order[#order + 1] = { r = r, n = counts[r] or 0 } end
    table.sort(order, function(a, b) return a.n > b.n end)
    if not main and order[1] and order[1].n > 0 then
        main = order[1].r
        mainSrc = "Bedarf-Würfe"
    end
    if not main and #possible == 1 then main = possible[1]; mainSrc = "einzige Rolle der Klasse" end
    local offs, offSrc = {}, nil
    for _, o in ipairs(order) do
        if o.r ~= main and o.n > 0 then offs[#offs + 1] = o.r end
    end
    if #offs > 0 then offSrc = "Bedarf-Würfe" end
    local others = {}
    for _, r in ipairs(possible) do if r ~= main then others[#others + 1] = r end end
    return main, mainSrc, offs, offSrc, others
end

-- passt die Item-Rolle zu Main- oder Offspec?
function GW.RoleFit(itemRoles, full, class)
    if not itemRoles or not next(itemRoles) then return nil end
    local main, _, offs, _, others = GW.PlayerRoles(full, class)
    if main and itemRoles[main] then return "main" end
    for _, r in ipairs(offs) do if itemRoles[r] then return "off" end end
    for _, r in ipairs(others) do if itemRoles[r] then return main and "off" or "possible" end end
    local possible = CLASS_ROLES[class or ""] or {}
    for _, r in ipairs(possible) do if itemRoles[r] then return "possible" end end
    return "none"
end

local VERDICT_TEXT = {
    ok = "|cff40ff40passt|r", frag = "|cffffd100fragwürdig|r", geier = "|cffff4040GEIER|r",
    info = "|cff888888-|r", pending = "|cff888888...|r",
}
GW.VERDICT_TEXT = VERDICT_TEXT
local ROLL_TEXT = { need = "Bedarf", offneed = "Bedarf (2. Spec)", greed = "Gier", de = "Entzaubern",
    pass = "Passe", won = "gewonnen", got = "erhalten" }
GW.ROLL_TEXT = ROLL_TEXT

---------------------------------------------------------------------------
-- Runs: jede Instanz-Runde bzw. Gruppen-Session getrennt fuehren
---------------------------------------------------------------------------
local RUN_IDLE = 90 * 60   -- so lange ohne Aktivitaet -> neuer Run

local function LootMethodName()
    local m
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        local ok, v = pcall(C_PartyInfo.GetLootMethod)
        if ok then m = v end
    elseif GetLootMethod then
        local ok, v = pcall(GetLootMethod)
        if ok then m = v end
    end
    m = S(m)
    local names = { freeforall = "Jeder gegen jeden", roundrobin = "Reihum", master = "Plündermeister",
        group = "Gruppenplündern", needbeforegreed = "Bedarf vor Gier", personalloot = "Persönliche Beute" }
    if type(m) == "number" and Enum and Enum.LootMethod then
        for k, v in pairs(Enum.LootMethod) do
            if v == m then m = k:lower() break end
        end
    end
    return type(m) == "string" and (names[m:lower()] or m) or nil
end

local function Place()
    local inInst, iType = IsInInstance()
    inInst = S(inInst)
    if inInst then
        local name, _, _, diffName = GetInstanceInfo()
        name, diffName = S(name), S(diffName)
        return name or "Instanz", true, S(iType), diffName
    end
    return S(GetRealZoneText and GetRealZoneText()) or "Unterwegs", false
end

function GW.CurrentRun()
    local d = GW.db()
    local r = d.runs and d.runs[1]
    if r and not r.stop and time() - (r.last or r.start) < RUN_IDLE then return r end
end

-- Gehoert der Run zu einer Gilde? (Mehrheit der Teilnehmer oder Gruppenleiter)
function GW.RunGuild(r)
    local cnt, total = {}, 0
    for full in pairs(r.members or {}) do
        total = total + 1
        local k = ns.db.players[full]
        if k then cnt[k] = (cnt[k] or 0) + 1 end
    end
    local best, bn = nil, 0
    for k, n in pairs(cnt) do if n > bn then best, bn = k, n end end
    if best and bn >= 3 and bn >= total * 0.4 then return best, "Mehrheit" end
    local lk = r.leader and ns.db.players[r.leader]
    if lk then return lk, "Gruppenleiter" end
end

function GW.EndRun(reason)
    local d = GW.db()
    local r = d.runs and d.runs[1]
    if not r or r.stop then return end
    r.stop = r.last or time()
    r.endReason = reason
    -- beobachtete Pluendermethode der Gilde des Runs zuschreiben (GScout-Lootsystem)
    if not r.lootEvDone and r.lootMethod and ns.LootEvidenceFromRun and (r.instance or (r.rolls or 0) > 0) then
        local gk, why = GW.RunGuild(r)
        local gg = gk and ns.db.guilds[gk]
        if gg then
            ns.LootEvidenceFromRun(gg, r.lootMethod)
            r.guild, r.guildWhy = gg.name, why
        end
        r.lootEvDone = true
    end
    -- leere Welt-Runs wegwerfen, Instanz-Runs behalten (Teilnehmer sind trotzdem interessant)
    if (r.rolls or 0) == 0 and not r.instance then table.remove(d.runs, 1) end
    GW.Refresh()
end

function GW.StartRun()
    local d = GW.db()
    d.runs = d.runs or {}
    GW.EndRun("neuer Run")
    d.runSeq = (d.runSeq or 0) + 1
    local zone, inst, iType, diff = Place()
    local r = { id = d.runSeq, start = time(), last = time(), zone = zone, instance = inst or nil,
        itype = iType, difficulty = diff, raid = IsInRaid() or nil, members = {}, rolls = 0, susp = 0,
        lootMethod = LootMethodName() }
    table.insert(d.runs, 1, r)
    while #d.runs > 100 do table.remove(d.runs) end
    GW.UpdateRunMembers()
    if inst then ns.Print("|cffff4040Geierwacht:|r neuer Run - " .. zone .. (diff and diff ~= "" and (" (" .. diff .. ")") or "")) end
    GW.Refresh()
    return r
end

-- Run fuer neue Beute: laufenden nehmen oder einen neuen beginnen
function GW.EnsureRun()
    local r = GW.CurrentRun()
    local zone, inst = Place()
    if r and inst and r.zone ~= zone then r = nil end   -- andere Instanz = anderer Run
    if not r then r = GW.StartRun() end
    r.last = time()
    return r
end

function GW.UpdateRunMembers()
    local r = GW.CurrentRun()
    if not r then return end
    local n = 0
    for _, unit in ipairs(GroupUnits()) do
        if UnitExists(unit) then
            local nm, rl = UnitName(unit)
            nm, rl = S(nm), S(rl)
            if nm then
                local full = ns.NormFull(ns.FullName(nm, rl))
                local _, cls = UnitClass(unit)
                r.members[full] = S(cls) or r.members[full] or true
                if UnitIsGroupLeader and S(UnitIsGroupLeader(unit)) then r.leader = full end
            end
        end
    end
    for _ in pairs(r.members) do n = n + 1 end
    r.size = n
    r.lootMethod = LootMethodName() or r.lootMethod
end

function GW.RunById(id)
    for _, r in ipairs(GW.db().runs or {}) do
        if r.id == id then return r end
    end
end

function GW.RunTitle(r)
    if not r then return "Alle Runs" end
    local t = date("%d.%m. %H:%M", r.start)
    return string.format("%s · %s", r.zone or "?", t)
end

-- Ort/Gruppe gewechselt?
function GW.OnPlaceChanged()
    local r = GW.CurrentRun()
    local zone, inst = Place()
    if inst and IsInGroup() then
        if not r or r.zone ~= zone then GW.StartRun() else r.last = time() end
    elseif r and r.instance and not inst then
        GW.EndRun("Instanz verlassen")
    end
end

function GW.PlayerLabel(p)
    if not p then return "" end
    local score = (p.geier or 0) * 2 + (p.frag or 0)
    if (p.geier or 0) >= 2 or score >= 4 then return "|cffff4040Geier|r", 2 end
    if score >= 2 then return "|cffffd100Verdächtig|r", 1 end
    return "|cff40ff40unauffällig|r", 0
end

local function Record(full, kind, link, roll)
    local d = GW.db()
    local now = time()
    -- Doppelte Meldungen (Chat + Beuteverlauf) zusammenfassen
    for i = 1, math.min(30, #d.history) do
        local h = d.history[i]
        if h.player == full and h.link == link and now - h.t < 300 then
            if kind == "won" or kind == "got" then h.won = true
            elseif roll and not h.roll then h.roll = roll
            elseif (kind == "need" or kind == "offneed") and h.kind ~= "need" and h.kind ~= "offneed" then h.kind = kind end
            GW.Refresh()
            return h
        end
    end
    -- "erhalten" nur fuer wertvolle Beute (ab Selten) aufnehmen, sonst flutet Grauzeug den Verlauf
    if kind == "got" then
        local inf = GetInfo(link)
        if inf and (inf.quality or 0) < 3 then return nil end
    end
    local cls, lvl = GW.PlayerInfo(full)
    local run = GW.EnsureRun()
    if kind == "need" or kind == "offneed" then run.rolls = (run.rolls or 0) + 1 end
    if cls then run.members[full] = cls end
    local h = { t = now, run = run.id, player = full, class = cls, level = lvl, kind = kind, link = link, roll = roll,
        won = (kind == "won" or kind == "got") or nil, zone = S(GetRealZoneText and GetRealZoneText()) }
    table.insert(d.history, 1, h)
    while #d.history > 250 do table.remove(d.history) end
    GW.Judge(h, 0)
    return h
end

-- Urteil faellen (wartet ggf., bis die Gegenstandsdaten geladen sind)
function GW.Judge(h, tries)
    if h.kind ~= "need" and h.kind ~= "offneed" and h.kind ~= "got" and h.kind ~= "won" then
        h.verdict, h.reason = "info", ""
        GW.Refresh()
        return
    end
    local v, reason, extra = GW.Evaluate(h.link, h.class, h.level)
    if v == "pending" and tries < 10 then
        C_Timer.After(0.5, function() GW.Judge(h, tries + 1) end)
        h.verdict, h.reason = "pending", reason
        GW.Refresh()
        return
    end
    -- "erhalten" (Plündermeister) nur fuer wertvolle Sachen bewerten
    if h.kind == "got" and extra and (extra.quality or 0) < 3 then v, reason = "info", "" end
    h.verdict, h.reason = v, reason
    h.boe = extra and extra.boe or nil
    if extra and extra.roles and next(extra.roles) then
        h.itemRoles = {}
        for k in pairs(extra.roles) do h.itemRoles[k] = true end
    end

    if v == "ok" or v == "frag" or v == "geier" then
        local d = GW.db()
        local p = d.players[h.player] or {}
        d.players[h.player] = p
        p.class = h.class or p.class
        p.level = h.level or p.level
        p.last = h.t
        if h.kind ~= "got" and h.kind ~= "won" then
            p.needs = (p.needs or 0) + 1
            -- welche Rolle sammelt der Spieler? (nur passende Wuerfe zaehlen)
            if v == "ok" and h.itemRoles then
                p.roleCounts = p.roleCounts or {}
                local poss = CLASS_ROLES[h.class or ""] or {}
                for _, r in ipairs(poss) do
                    if h.itemRoles[r] then p.roleCounts[r] = (p.roleCounts[r] or 0) + 1 end
                end
            end
        end
        h.fit = GW.RoleFit(h.itemRoles, h.player, h.class)
        -- Bedarf (Mainspec) auf reine Offspec-Beute: je nach Gruppenregel fragwuerdig
        if h.fit == "off" and h.kind == "need" and v == "ok" and ns.db.settings.lootMSOS then
            v = "frag"
            h.verdict = v
            h.reason = "Offspec-Gegenstand, aber Mainspec-Bedarf (Regel MS>OS)"
        end
        if v ~= "ok" then
            local run = h.run and GW.RunById(h.run)
            if run then run.susp = (run.susp or 0) + 1 end
        end
        if v == "frag" then p.frag = (p.frag or 0) + 1 end
        if v == "geier" then p.geier = (p.geier or 0) + 1 end
        if v ~= "ok" and ns.db.settings.lootAlerts ~= false then
            local name = ns.SplitName(h.player)
            local main = GW.PlayerRoles(h.player, h.class)
            ns.Print(string.format("|cffff4040Geierwacht:|r %s%s|r (%s%s) %s %s - %s: %s",
                ClassColor(h.class or ""), name, ClassName(h.class or "?"),
                main and (", Main " .. ROLE_NAMES[main]) or "",
                h.kind == "got" and "erhält" or "würfelt Bedarf auf", h.link or "?", VERDICT_TEXT[v], h.reason or reason))
        end
    end
    GW.Refresh()
end

---------------------------------------------------------------------------
-- Beute-Chat auswerten (sprachunabhaengig ueber die Blizzard-Textvorlagen)
---------------------------------------------------------------------------
local function FmtToPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local order, n, pat, i = {}, 0, {}, 1
    while i <= #fmt do
        local a, b, num, typ = fmt:find("^%%(%d?)%$?([sd])", i)
        if a then
            n = n + 1
            order[n] = tonumber(num) or n
            pat[#pat + 1] = (typ == "d") and "(%d+)" or "(.-)"
            i = b + 1
        else
            local ch = fmt:sub(i, i)
            if ch:find("[%^%$%(%)%.%[%]%*%+%-%?%%]") then ch = "%" .. ch end
            pat[#pat + 1] = ch
            i = i + 1
        end
    end
    return "^" .. table.concat(pat) .. "$", order
end

-- { Vorlage, Art, Position Spieler (nil = ich), Position Gegenstand, Position Wurf }
local TEMPLATES = {
    { "LOOT_ROLL_NEED", "need", 1, 2 },
    { "LOOT_ROLL_NEED_SELF", "need", nil, 1 },
    { "LOOT_ROLL_GREED", "greed", 1, 2 },
    { "LOOT_ROLL_GREED_SELF", "greed", nil, 1 },
    { "LOOT_ROLL_DISENCHANT", "de", 1, 2 },
    { "LOOT_ROLL_DISENCHANT_SELF", "de", nil, 1 },
    { "LOOT_ROLL_PASSED", "pass", 1, 2 },
    { "LOOT_ROLL_PASSED_SELF", "pass", nil, 1 },
    { "LOOT_ROLL_WON", "won", 1, 2 },
    { "LOOT_ROLL_YOU_WON", "won", nil, 1 },
    { "LOOT_ROLL_ROLLED_NEED", "need", 3, 2, 1 },
    { "LOOT_ROLL_ROLLED_GREED", "greed", 3, 2, 1 },
    { "LOOT_ITEM_MULTIPLE", "got", 1, 2 },
    { "LOOT_ITEM", "got", 1, 2 },
    { "LOOT_ITEM_SELF_MULTIPLE", "got", nil, 1 },
    { "LOOT_ITEM_SELF", "got", nil, 1 },
}
local compiled

local function Compile()
    compiled = {}
    for _, t in ipairs(TEMPLATES) do
        local pat, order = FmtToPattern(_G[t[1]])
        if pat then compiled[#compiled + 1] = { pat = pat, order = order, kind = t[2], pp = t[3], ip = t[4], rp = t[5] } end
    end
end

function GW.ParseLootMessage(msg)
    if not compiled then Compile() end
    for _, c in ipairs(compiled) do
        local caps = { msg:match(c.pat) }
        if #caps > 0 then
            local args = {}
            for k, v in ipairs(caps) do args[c.order[k] or k] = v end
            local link = args[c.ip]
            if link and link:find("|Hitem:", 1, true) then
                local player = c.pp and args[c.pp] or ns.playerFull
                return c.kind, player, link, c.rp and tonumber(args[c.rp]) or nil
            end
        end
    end
end

function GW.OnLootChat(msg)
    if ns.db.settings.lootWatch == false then return end
    if msg ~= nil and S(msg) == nil then
        GW.secret = (GW.secret or 0) + 1
        return
    end
    msg = S(msg)
    if not msg then return end
    GW.seen = (GW.seen or 0) + 1
    local kind, player, link, roll = GW.ParseLootMessage(msg)
    if not kind then return end
    player = S(player)
    if not player then return end
    player = player:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
    local full = ns.NormFull(player:find("-", 1, true) and player or ns.FullName(player))
    if kind == "pass" then return end
    Record(full, kind, link:match("(|c%x+|Hitem:.-|h.-|h|r)") or link, roll)
end

---------------------------------------------------------------------------
-- Beuteverlauf (modernes System), falls Forever ihn liefert
---------------------------------------------------------------------------
local STATE = {}   -- Enum.EncounterLootDropRollState
if Enum and Enum.EncounterLootDropRollState then
    local E = Enum.EncounterLootDropRollState
    if E.NeedMainSpec then STATE[E.NeedMainSpec] = "need" end
    if E.NeedOffSpec then STATE[E.NeedOffSpec] = "offneed" end
    if E.Greed then STATE[E.Greed] = "greed" end
    if E.Transmog then STATE[E.Transmog] = "greed" end
end

function GW.OnLootHistory(encounterID, lootListID)
    if ns.db.settings.lootWatch == false then return end
    if not (C_LootHistory and C_LootHistory.GetSortedInfoForDrop) then return end
    local ok, drop = pcall(C_LootHistory.GetSortedInfoForDrop, encounterID, lootListID)
    if not ok or type(drop) ~= "table" then return end
    local link = S(drop.itemHyperlink)
    if not link then return end
    for _, r in ipairs(drop.rollInfos or {}) do
        local name = S(r.playerName)
        local kind = STATE[S(r.state) or -1]
        if name and kind then
            local full = ns.NormFull(name:find("-", 1, true) and name or ns.FullName(name))
            local h = Record(full, kind, link, S(r.roll))
            if h and not h.class and S(r.playerClass) then
                h.class = S(r.playerClass)
                GW.Judge(h, 0)
            end
            if h and S(r.isWinner) then h.won = true end
        end
    end
end

---------------------------------------------------------------------------
-- Warnung, wenn ein markierter Geier in die Gruppe kommt
---------------------------------------------------------------------------
local warned = {}
function GW.CheckGroup()
    local d = GW.db()
    for _, unit in ipairs(GroupUnits()) do
        if unit ~= "player" and UnitExists(unit) then
            local n, r = UnitName(unit)
            n, r = S(n), S(r)
            if n then
                local full = ns.NormFull(ns.FullName(n, r))
                local p = d.players[full]
                local _, lvl = GW.PlayerLabel(p)
                if (d.marked[full] or lvl == 2) and not warned[full] then
                    warned[full] = true
                    ns.Print(string.format("|cffff4040Geierwacht: Achtung!|r %s ist %s%s",
                        n, d.marked[full] and "als Geier markiert" or "auffällig",
                        d.marked[full] and d.marked[full].note and d.marked[full].note ~= "" and (" (" .. d.marked[full].note .. ")") or ""))
                end
            end
        end
    end
end

function GW.Mark(full, on, note)
    local d = GW.db()
    if on then d.marked[full] = { t = time(), note = note or "" } else d.marked[full] = nil end
    GW.Refresh()
end

-- Tooltip-Zeile fuer Spieler
local function OnTooltip(tooltip)
    if tooltip ~= GameTooltip or not ns.db or ns.db.settings.lootWatch == false then return end
    local _, unit = tooltip:GetUnit()
    unit = S(unit)
    if not unit or not S(UnitIsPlayer(unit)) then return end
    local n, r = UnitName(unit)
    n, r = S(n), S(r)
    if not n then return end
    local full = ns.NormFull(ns.FullName(n, r))
    local d = GW.db()
    local p, m = d.players[full], d.marked[full]
    if not p and not m then return end
    local label, lvl = GW.PlayerLabel(p)
    if m then
        tooltip:AddLine("|cffff4040Geierwacht: als Geier markiert|r" .. (m.note ~= "" and (" - " .. m.note) or ""), 1, 1, 1, true)
    elseif lvl > 0 then
        tooltip:AddLine(string.format("Geierwacht: %s (%d fragwürdig, %d Geier bei %d Bedarf)", label,
            p.frag or 0, p.geier or 0, p.needs or 0), 1, 1, 1, true)
    end
end

function GW.Refresh() end   -- wird von der Oberflaeche ersetzt

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if ns.db.settings.lootWatch == nil then ns.db.settings.lootWatch = true end
        if ns.db.settings.lootAlerts == nil then ns.db.settings.lootAlerts = true end
        if ns.db.settings.lootSpecInspect == nil then ns.db.settings.lootSpecInspect = true end
        if ns.db.settings.lootMSOS == nil then ns.db.settings.lootMSOS = false end
        GW.db()
        pcall(ev.RegisterEvent, ev, "CHAT_MSG_LOOT")
        pcall(ev.RegisterEvent, ev, "LOOT_HISTORY_UPDATE_DROP")
        pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
        pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
        pcall(ev.RegisterEvent, ev, "ZONE_CHANGED_NEW_AREA")
        if TooltipDataProcessor and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(OnTooltip, tt) end)
        end
    elseif event == "CHAT_MSG_LOOT" then
        local ok, err = pcall(GW.OnLootChat, (...))
        if not ok then GW.lastError = tostring(err) end
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then
        local ok, err = pcall(GW.OnLootHistory, ...)
        if not ok then GW.lastError = tostring(err) end
    elseif event == "GROUP_ROSTER_UPDATE" then
        if not IsInGroup() then
            pcall(GW.EndRun, "Gruppe verlassen")
            return
        end
        if not GW.groupQueued then
            GW.groupQueued = true
            C_Timer.After(3, function()
                GW.groupQueued = false
                pcall(GW.CheckGroup)
                pcall(GW.UpdateRunMembers)
                pcall(GW.OnPlaceChanged)
            end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(2, function() pcall(GW.OnPlaceChanged) end)
    end
end)
