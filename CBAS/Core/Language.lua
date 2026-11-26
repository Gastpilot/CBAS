-- CBAS (Craphunts Blacklisted Addon Suite) - Sprache & Laendertag aus Rekrutierungstexten
local ADDON, ns = ...

-- Haeufige Woerter je Sprache (mit Leerzeichen, damit nur ganze Woerter zaehlen)
local WORDS = {
    DE = { " und ", " wir ", " suchen ", " sucht ", " für ", " noch ", " mit ", " ist ", " gilde", " nicht ",
           " auch ", " uhr", " eine ", " der ", " die ", " das ", " sind ", " euch ", " uns ", " meldet ", " spieler" },
    EN = { " the ", " and ", " we ", " for ", " looking ", " guild", " with ", " are ", " is ", " our ",
           " you ", " pm ", " server time", " all ", " players", " join ", " whisper", " more " },
    FR = { " et ", " nous ", " pour ", " recrute", " guilde", " avec ", " les ", " des ", " est ", " joueurs",
           " cherche", " une ", " sur ", " vous " },
    ES = { " para ", " buscamos", " jugadores", " hermandad", " los ", " las ", " con ", " somos ", " reclut",
           " una ", " que ", " del " },
    IT = { " cerchiamo", " gilda", " giocatori", " siamo ", " il ", " della ", " per ", " che ", " gli " },
    PT = { " guilda", " jogadores", " estamos", " com ", " procura", " recrutando", " nós ", " uma " },
    PL = { " gildia", " szukamy", " graczy", " dla ", " jest ", " oraz ", " nas " },
    NL = { " zoeken", " spelers", " voor ", " wij ", " onze ", " het ", " een " },
}

-- Ausdrueckliche Angaben in der Werbung ("[DE]", "deutschsprachig", "english speaking" ...)
local TAGS = {
    { "%[de%]", "DE" }, { "%(de%)", "DE" }, { "%f[%w]de/at", "DE" }, { "%f[%w]dach%f[%W]", "DE" },
    { "deutschsprachig", "DE" }, { "deutsche gilde", "DE" }, { "%f[%w]german%f[%W]", "DE" },
    { "%f[%w]ger%f[%W]", "DE" }, { "%f[%w]deutsch%f[%W]", "DE" },
    { "%[en%]", "EN" }, { "%(en%)", "EN" }, { "english speaking", "EN" }, { "%f[%w]english%f[%W]", "EN" },
    { "englischsprachig", "EN" }, { "%f[%w]international%f[%W]", "EN" },
    { "%[fr%]", "FR" }, { "%(fr%)", "FR" }, { "français", "FR" }, { "francais", "FR" }, { "french", "FR" },
    { "francophone", "FR" },
    { "%[es%]", "ES" }, { "%(es%)", "ES" }, { "español", "ES" }, { "espanol", "ES" }, { "spanish", "ES" },
    { "%[it%]", "IT" }, { "italiano", "IT" }, { "italian", "IT" },
    { "%[pt%]", "PT" }, { "%[br%]", "PT" }, { "português", "PT" }, { "portugues", "PT" },
    { "%[pl%]", "PL" }, { "polski", "PL" }, { "polish", "PL" },
    { "%[nl%]", "NL" }, { "nederlands", "NL" }, { "dutch", "NL" },
    { "%[ru%]", "RU" }, { "russian", "RU" },
}

local COUNTRIES = {
    { "%f[%w]de/at/ch%f[%W]", { "DE", "AT", "CH" } }, { "%f[%w]dach%f[%W]", { "DE", "AT", "CH" } },
    { "österreich", { "AT" } }, { "%f[%w]austria", { "AT" } }, 
    { "schweiz", { "CH" } }, { "%f[%w]swiss", { "CH" } },
    { "deutschland", { "DE" } }, { "germany", { "DE" } },
    { "%f[%w]uk%f[%W]", { "UK" } }, { "british", { "UK" } }, { "england", { "UK" } },
    { "%f[%w]usa%f[%W]", { "US" } }, { "america", { "US" } },
    { "frankreich", { "FR" } }, { "france", { "FR" } },
    { "spanien", { "ES" } }, { "españa", { "ES" } }, { "spain", { "ES" } },
    { "italien", { "IT" } }, { "italia", { "IT" } },
    { "polen", { "PL" } }, { "polska", { "PL" } }, { "poland", { "PL" } },
    { "niederlande", { "NL" } }, { "netherlands", { "NL" } }, { "belgien", { "BE" } }, { "belgium", { "BE" } },
    { "skandinav", { "SE", "NO", "DK" } }, { "nordic", { "SE", "NO", "DK", "FI" } },
}

ns.LANG_NAMES = {
    DE = "Deutsch", EN = "Englisch", FR = "Französisch", ES = "Spanisch", IT = "Italienisch",
    PT = "Portugiesisch", PL = "Polnisch", NL = "Niederländisch", RU = "Russisch",
}

-- Rueckgabe: Sprachcode (oder nil), "ausdruecklich?"
function ns.DetectLanguage(text)
    local low = " " .. text:lower():gsub("[%p]", " ") .. " "
    local lowRaw = text:lower()
    for _, t in ipairs(TAGS) do
        if lowRaw:find(t[1]) then return t[2], true end
    end
    -- kyrillische Schrift (UTF-8: Bytes 0xD0/0xD1)
    local cyr = 0
    for _ in text:gmatch("[\208\209][\128-\191]") do cyr = cyr + 1 end
    if cyr >= 5 then return "RU", false end
    local best, bestScore, second = nil, 0, 0
    for code, words in pairs(WORDS) do
        local sc = 0
        for _, w in ipairs(words) do
            if low:find(w, 1, true) then sc = sc + 1 end
        end
        if sc > bestScore then
            second = bestScore
            best, bestScore = code, sc
        elseif sc > second then
            second = sc
        end
    end
    if bestScore >= 2 and bestScore > second then return best, false end
end

function ns.DetectCountries(text)
    local low = text:lower()
    local found
    for _, c in ipairs(COUNTRIES) do
        if low:find(c[1]) then
            found = found or {}
            for _, cc in ipairs(c[2]) do found[cc] = true end
        end
    end
    return found
end

-- Ergebnis auf die Gilde anwenden: ausdrueckliche Angaben schlagen Wortstatistik
function ns.ApplyLanguage(g, text)
    local code, explicit = ns.DetectLanguage(text)
    if code then
        g.langVotes = g.langVotes or {}
        g.langVotes[code] = (g.langVotes[code] or 0) + (explicit and 5 or 1)
        if explicit then g.langTag = code end
        local best, bv = nil, 0
        for c, v in pairs(g.langVotes) do
            if v > bv then best, bv = c, v end
        end
        g.lang = g.langTag or best
    end
    local cs = ns.DetectCountries(text)
    if cs then
        g.countries = g.countries or {}
        for c in pairs(cs) do g.countries[c] = true end
    end
end

-- Kurzer Tag fuer die Liste, z.B. "DE" oder "DE·AT"
function ns.LangTag(g)
    local t = g.lang or ""
    if g.countries then
        local cs = {}
        for c in pairs(g.countries) do if c ~= t then cs[#cs + 1] = c end end
        table.sort(cs)
        if #cs > 0 then t = (t ~= "" and (t .. "·") or "") .. table.concat(cs, "·") end
    end
    return t
end

function ns.CountryList(g)
    local cs = {}
    for c in pairs(g.countries or {}) do cs[#cs + 1] = c end
    table.sort(cs)
    return table.concat(cs, ", ")
end
