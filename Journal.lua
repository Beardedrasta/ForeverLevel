-- ============================================================
-- FOREVER LEVEL v1.3.0
-- Journal.lua - COMPLETE REPLACEMENT
-- ============================================================

local _, FL = ...
local J

local TABS = {
    { "session",    "SESSION" },
    { "lifetime",   "LIFETIME" },
    { "sources",    "SOURCES" },
    { "efficiency", "EFFICIENCY" },
    { "zones",      "ZONES" },
    { "history",    "HISTORY" },
}

local labels = {
    "Character level",
    "Current XP",
    "XP remaining",
    "XP earned",
    "Kills recorded",
    "Kill XP",
    "Average kill XP",
    "Quests completed",
    "Quest XP",
    "Average quest XP",
    "Session XP/hour",
    "Recent XP/hour",
    "Time to level",
    "Kill XP contribution",
    "Quest XP contribution",
    "Unclassified XP",
}

local function Text(parent, template)
    return FL:Text(parent, template)
end

local function Heading(parent, label, y)
    local t = Text(parent, "GameFontNormal")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", 17, y)
    t:SetText(label)
    t:SetTextColor(unpack(FL.GOLD))
    return t
end

local function NewView(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    return f
end

local function MakeLine(parent, y, name)
    local l = Text(parent, "GameFontHighlight")
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, y)
    l:SetWidth(225)
    l:SetJustifyH("LEFT")
    l:SetText(name)
    l:SetTextColor(0.75, 0.69, 0.58)

    local r = Text(parent, "GameFontNormal")
    r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, y)
    r:SetWidth(155)
    r:SetJustifyH("RIGHT")
    r:SetTextColor(1, 0.88, 0.66)
    r:SetText("--")

    return r
end

local function MakeScroll(parent, top)
    local scroll = CreateFrame(
        "ScrollFrame", nil, parent,
        "UIPanelScrollFrameTemplate"
    )

    scroll:SetPoint(
        "TOPLEFT", parent, "TOPLEFT", 12, top
    )
    scroll:SetPoint(
        "BOTTOMRIGHT", parent, "BOTTOMRIGHT", -31, 12
    )

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(358, 350)
    scroll:SetScrollChild(content)

    return scroll, content
end

local function MakeRows(content, count, height)
    local rows = {}

    for i = 1, count do
        local t = Text(
            content, "GameFontHighlightSmall"
        )
        t:SetPoint(
            "TOPLEFT", content, "TOPLEFT",
            5, -6 - (i - 1) * height
        )
        t:SetSize(348, height - 4)
        t:SetJustifyH("LEFT")
        t:SetJustifyV("TOP")
        t:SetTextColor(0.88, 0.77, 0.57)
        t:Hide()

        rows[i] = t
    end

    return rows
end

local function MakeBar(parent, y, label, color)
    local title = Text(parent, "GameFontNormal")
    title:SetPoint(
        "TOPLEFT", parent, "TOPLEFT", 18, y
    )
    title:SetText(label)
    title:SetTextColor(unpack(color))

    local number = Text(
        parent, "GameFontHighlightSmall"
    )
    number:SetPoint(
        "TOPRIGHT", parent, "TOPRIGHT", -18, y
    )
    number:SetWidth(190)
    number:SetJustifyH("RIGHT")

    local background = parent:CreateTexture(
        nil, "BACKGROUND"
    )
    background:SetTexture(FL.WHITE)
    background:SetVertexColor(0.16, 0.14, 0.11, 1)
    background:SetPoint(
        "TOPLEFT", parent, "TOPLEFT", 18, y - 24
    )
    background:SetSize(370, 13)

    local fill = parent:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(FL.WHITE)
    fill:SetVertexColor(unpack(color))
    fill:SetPoint("LEFT", background, "LEFT", 0, 0)
    fill:SetSize(1, 13)

    return { amount = number, fill = fill }
end

local function SetBar(bar, value, maximum, suffix)
    local p = 0

    if maximum > 0 then
        p = FL:Clamp(value / maximum, 0, 1)
    end

    bar.fill:SetWidth(math.max(1, 370 * p))
    bar.fill:SetShown(p > 0)

    bar.amount:SetText(
        FL:Comma(value)
        .. (suffix or "")
        .. string.format(" | %.1f%%", p * 100)
    )
end

local function RecordRate(record)
    if not record or not record.completeTiming
        or not record.levelSeconds
        or record.levelSeconds < 60
        or not record.observedXP
        or record.observedXP <= 0 then
        return nil
    end

    return record.observedXP * 3600
        / record.levelSeconds
end

-- ============================================================
-- BUILD JOURNAL
-- ============================================================

function FL:BuildJournal()
    J = CreateFrame(
        "Frame", "ForeverLevelJournal",
        UIParent, "BackdropTemplate"
    )

    self.journal = J
    self.journalFrames = {}

    J:SetSize(460, 555)
    J:SetPoint("CENTER")
    J:SetFrameStrata("DIALOG")
    J:SetClampedToScreen(true)
    J:SetMovable(true)
    J:EnableMouse(true)
    J:RegisterForDrag("LeftButton")

    self:Style(J, 0.99, 18)

    J:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    J:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local title = Text(J, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", J, "TOPLEFT", 18, -16)
    title:SetText("FOREVER LEVEL")
    title:SetTextColor(unpack(self.GOLD))

    local subtitle = Text(
        J, "GameFontHighlightSmall"
    )
    subtitle:SetPoint(
        "TOPLEFT", J, "TOPLEFT", 19, -39
    )
    subtitle:SetText("LEVELING JOURNAL | v1.3.0")

    local close = self:Button(
        J, "X", 25, 24, function() J:Hide() end
    )
    close:SetPoint(
        "TOPRIGHT", J, "TOPRIGHT", -12, -12
    )

    -- Six compact navigation tabs.
    J.tabs = {}

    for i, entry in ipairs(TABS) do
        local key = entry[1]

        local b = self:Button(
            J, entry[2], 68, 26,
            function()
                FL.db.journalTab = key
                FL:UpdateJournal()
            end
        )

        b:SetPoint(
            "TOPLEFT", J, "TOPLEFT",
            18 + (i - 1) * 71, -69
        )

        J.tabs[key] = b
    end

    local panel = CreateFrame(
        "Frame", nil, J, "BackdropTemplate"
    )
    panel:SetPoint(
        "TOPLEFT", J, "TOPLEFT", 16, -110
    )
    panel:SetPoint(
        "BOTTOMRIGHT", J, "BOTTOMRIGHT", -16, 49
    )
    self:Style(panel, 0.90, 12)
    table.insert(self.journalFrames, panel)

    J.views = {}

    -- Session and Lifetime.
    local stats = NewView(panel)
    J.views.stats = stats
    J.values = {}

    for i, label in ipairs(labels) do
        J.values[i] = MakeLine(
            stats, -16 - (i - 1) * 23, label
        )
    end

    -- XP Sources.
    local sources = NewView(panel)
    J.views.sources = sources

    Heading(sources, "OBSERVED XP DISTRIBUTION", -20)

    J.sourceScope = self:Button(
        sources, "Session Sources", 140, 26,
        function()
            FL.db.sourceScope =
                FL.db.sourceScope == "lifetime"
                and "session" or "lifetime"

            FL:UpdateJournal()
        end
    )
    J.sourceScope:SetPoint(
        "TOPRIGHT", sources, "TOPRIGHT", -16, -15
    )

    J.sourceBars = {
        kill = MakeBar(
            sources, -68, "KILL XP",
            { 0.81, 0.63, 0.33 }
        ),
        quest = MakeBar(
            sources, -148, "QUEST XP",
            { 0.37, 0.58, 0.82 }
        ),
        other = MakeBar(
            sources, -228, "UNCLASSIFIED XP",
            { 0.56, 0.53, 0.48 }
        ),
    }

    J.sourceTotal = Text(
        sources, "GameFontNormalLarge"
    )
    J.sourceTotal:SetPoint(
        "TOPLEFT", sources, "TOPLEFT", 18, -310
    )
    J.sourceTotal:SetTextColor(1, 0.88, 0.66)

    local sourceNote = Text(
        sources, "GameFontHighlightSmall"
    )
    sourceNote:SetPoint(
        "TOPLEFT", sources, "TOPLEFT", 18, -346
    )
    sourceNote:SetWidth(377)
    sourceNote:SetJustifyH("LEFT")
    sourceNote:SetText(
        "XP sources are approximated from reward events. "
        .. "Unclassified XP includes rewards that could "
        .. "not be matched to kills or quests."
    )

    -- Efficiency.
    local efficiency = NewView(panel)
    J.views.efficiency = efficiency

    Heading(
        efficiency, "LEVELING EFFICIENCY", -19
    )

    local efficiencyFields = {
        { "Session duration",                -57 },
        { "Estimated active time",           -86 },
        { "Estimated inactive time",         -115 },
        { "Activity percentage",             -144 },
        { "Full session XP/hour",            -190 },
        { "Recent 5-minute XP/hour",         -219 },
        { "Active XP/hour",                  -248 },
        { "Peak completed 5-minute XP/hour", -277 },
        { "Session XP gained",               -306 },
        { "Activity window",                 -335 },
    }

    J.efficiencyValues = {}

    for i, entry in ipairs(efficiencyFields) do
        J.efficiencyValues[i] = MakeLine(
            efficiency, entry[2], entry[1]
        )
    end

    local effTrack = efficiency:CreateTexture(
        nil, "BACKGROUND"
    )
    effTrack:SetTexture(FL.WHITE)
    effTrack:SetVertexColor(0.17, 0.15, 0.12)
    effTrack:SetPoint(
        "TOPLEFT", efficiency, "TOPLEFT", 18, -167
    )
    effTrack:SetSize(370, 9)

    J.efficiencyFill = efficiency:CreateTexture(
        nil, "ARTWORK"
    )
    J.efficiencyFill:SetTexture(FL.WHITE)
    J.efficiencyFill:SetVertexColor(
        0.85, 0.66, 0.33, 1
    )
    J.efficiencyFill:SetPoint(
        "LEFT", effTrack, "LEFT", 0, 0
    )
    J.efficiencyFill:SetSize(1, 9)

    local effNote = Text(
        efficiency, "GameFontHighlightSmall"
    )
    effNote:SetPoint(
        "TOPLEFT", efficiency, "TOPLEFT", 18, -370
    )
    effNote:SetWidth(377)
    effNote:SetJustifyH("LEFT")
    effNote:SetText(
        "Activity is estimated from XP reward timing. "
        .. "The peak rate uses observed completed "
        .. "five-minute windows. Neither metric is "
        .. "a direct measure of combat time."
    )
    effNote:SetTextColor(0.69, 0.65, 0.57)

    -- Zones.
    local zones = NewView(panel)
    J.views.zones = zones

    Heading(
        zones, "ZONE LEVELING PERFORMANCE", -15
    )

    J.zoneSummary = Text(
        zones, "GameFontHighlightSmall"
    )
    J.zoneSummary:SetPoint(
        "TOPLEFT", zones, "TOPLEFT", 15, -39
    )
    J.zoneSummary:SetWidth(385)
    J.zoneSummary:SetJustifyH("LEFT")
    J.zoneSummary:SetTextColor(0.77, 0.69, 0.52)

    J.zoneScroll, J.zoneContent =
        MakeScroll(zones, -76)

    J.zoneRows = MakeRows(
        J.zoneContent, 100, 63
    )

    -- History.
    local history = NewView(panel)
    J.views.history = history

    Heading(
        history, "LEVEL-TO-LEVEL PERFORMANCE", -15
    )

    J.historyScroll, J.historyContent =
        MakeScroll(history, -44)

    J.historyRows = MakeRows(
        J.historyContent, 100, 73
    )

    J.emptyHistory = Text(
        history, "GameFontHighlight"
    )
    J.emptyHistory:SetPoint(
        "TOP", history, "TOP", 0, -76
    )
    J.emptyHistory:SetWidth(345)
    J.emptyHistory:SetJustifyH("CENTER")
    J.emptyHistory:SetText(
        "No level-ups recorded yet.\n\n"
        .. "Your next level-up will appear here."
    )
    J.emptyHistory:SetTextColor(
        0.85, 0.73, 0.52
    )

    -- Footer.
    local reset = self:Button(
        J, "Reset Session", 135, 25,
        function()
            FL:ResetSession()
            FL:Refresh()
            FL:UpdateJournal()
            FL:Say("Session reset; lifetime preserved.")
        end
    )
    reset:SetPoint(
        "BOTTOMLEFT", J, "BOTTOMLEFT", 18, 13
    )

    local config = self:Button(
        J, "Configuration", 135, 25,
        function()
            J:Hide()
            FL:ToggleConfig(true)
        end
    )
    config:SetPoint("LEFT", reset, "RIGHT", 9, 0)

    J:Hide()
end

-- ============================================================
-- SOURCE VIEW
-- ============================================================

local function UpdateSources()
    local scope = FL.db.sourceScope == "lifetime"
        and "lifetime" or "session"

    J.sourceScope:SetText(
        scope == "lifetime"
        and "Lifetime Sources"
        or "Session Sources"
    )

    local source = scope == "lifetime"
        and FL.db.lifetime or FL.session

    local kill, quest, other, total =
        FL:Breakdown(source)

    SetBar(J.sourceBars.kill, kill, total, " XP")
    SetBar(J.sourceBars.quest, quest, total, " XP")
    SetBar(J.sourceBars.other, other, total, " XP")

    J.sourceTotal:SetText(
        "TOTAL OBSERVED XP: " .. FL:Comma(total)
    )
end

-- ============================================================
-- EFFICIENCY VIEW
-- ============================================================

local function UpdateEfficiency()
    local data = FL:EfficiencyData()

    local inactive = math.max(
        0, data.elapsed - data.active
    )

    local values = {
        FL:Duration(data.elapsed),
        FL:Duration(data.active),
        FL:Duration(inactive),
        string.format(
            "%.1f%%", data.activityPercent
        ),
        FL:Comma(data.sessionRate),
        FL:Comma(data.recentRate),
        FL:Comma(data.activeRate),
        FL:Comma(data.peakRate),
        FL:Comma(data.totalXP),
        tostring(data.activityWindow) .. " seconds",
    }

    for i, field in ipairs(J.efficiencyValues) do
        field:SetText(values[i] or "--")
    end

    local fraction = FL:Clamp(
        data.activityPercent / 100, 0, 1
    )

    J.efficiencyFill:SetWidth(
        math.max(1, 370 * fraction)
    )
    J.efficiencyFill:SetShown(fraction > 0)
end

-- ============================================================
-- ZONE VIEW
-- ============================================================

local function UpdateZones()
    local entries = FL:ZoneRows()
    local count = math.min(#entries, 100)
    local best = FL:BestZone()

    if best then
        J.zoneSummary:SetText(
            "Best sampled: " .. best.name
            .. " (" .. FL:Comma(best.rate)
            .. " XP/hr)"
        )
    else
        J.zoneSummary:SetText(
            "A zone needs 2 minutes and 100 XP "
            .. "for a rate estimate."
        )
    end

    J.zoneContent:SetHeight(
        math.max(320, count * 63 + 10)
    )

    for i, row in ipairs(J.zoneRows) do
        if i <= count then
            local e = entries[i]
            local z = e.data

            row:SetText(string.format(
                "%d. %s\n"
                .. "XP: %s   Time: %s   %s\n"
                .. "Kills: %s   Quests: %s",
                i,
                e.name,
                FL:Comma(z.gained),
                FL:Duration(z.seconds or 0),
                e.rate and (
                    FL:Comma(e.rate) .. " XP/hr"
                ) or "Insufficient data",
                FL:Comma(z.kills),
                FL:Comma(z.quests)
            ))

            row:Show()
        else
            row:Hide()
        end
    end

    if count == 0 then
        J.zoneRows[1]:SetText(
            "No zone statistics recorded yet."
        )
        J.zoneRows[1]:Show()
    end
end

-- ============================================================
-- HISTORY VIEW
-- ============================================================

local function UpdateHistory()
    local records = FL.db.levelHistory
    local count = math.min(#records, 100)

    J.historyScroll:SetShown(count > 0)
    J.emptyHistory:SetShown(count == 0)

    J.historyContent:SetHeight(
        math.max(320, count * 73 + 10)
    )

    for i, row in ipairs(J.historyRows) do
        if i <= count then
            local index = #records - i + 1
            local record = records[index]
            local previous = records[index - 1]

            local stamp = record.time
                and date(
                    "%m/%d/%Y %H:%M", record.time
                ) or "Unknown"

            local elapsed = record.completeTiming
                and record.levelSeconds
                and FL:Duration(record.levelSeconds)
                or "Not fully observed"

            local rate = RecordRate(record)
            local previousRate = RecordRate(previous)

            local comparison = ""

            if rate and previousRate
                and previous.to == record.from then
                comparison = string.format(
                    " | %+0.1f%%",
                    (rate / previousRate - 1) * 100
                )
            end

            row:SetText(string.format(
                "LEVEL %s -> %s  |  %s\n"
                .. "Time: %s\n"
                .. "Rate: %s%s\n"
                .. "XP: %s   Kills: %s   Quests: %s",
                tostring(record.from),
                tostring(record.to),
                stamp,
                elapsed,
                rate and (
                    FL:Comma(rate) .. "/hr"
                ) or "--",
                comparison,
                FL:Comma(record.observedXP),
                FL:Comma(record.kills),
                FL:Comma(record.quests)
            ))

            row:Show()
        else
            row:Hide()
        end
    end
end

-- ============================================================
-- SESSION / LIFETIME VIEW
-- ============================================================

local function UpdateStats(tab)
    local source = tab == "lifetime"
        and FL.db.lifetime or FL.session

    local _, xp, maximum, remaining =
        FL:XPData()

    local kill, quest, other, total =
        FL:Breakdown(source)

    local function Percent(v)
        if total <= 0 then return "0.0%" end
        return string.format(
            "%.1f%%", v * 100 / total
        )
    end

    local rate = FL:SelectedRate()

    local eta = tab == "session"
        and rate and rate > 0 and remaining
        and FL:Duration(remaining * 3600 / rate)
        or nil

    local values = {
        tostring(UnitLevel("player")),
        FL:Comma(xp) .. " / " .. FL:Comma(maximum),
        FL:Comma(remaining),
        FL:Comma(source.gained),
        FL:Comma(source.kills),
        FL:Comma(source.killXP),
        source.kills > 0
        and FL:Comma(source.killXP / source.kills)
        or "--",
        FL:Comma(source.quests),
        FL:Comma(source.questXP),
        source.quests > 0
        and FL:Comma(source.questXP / source.quests)
        or "--",
        tab == "session"
        and FL:Comma(FL:SessionRate())
        or "Session only",
        tab == "session"
        and FL:Comma(FL:RecentRate())
        or "Session only",
        tab == "session"
        and (eta or "Calculating")
        or "Session only",
        FL:Comma(kill) .. " (" .. Percent(kill) .. ")",
        FL:Comma(quest) .. " (" .. Percent(quest) .. ")",
        FL:Comma(other) .. " (" .. Percent(other) .. ")",
    }

    for i, field in ipairs(J.values) do
        field:SetText(values[i] or "--")
    end
end

-- ============================================================
-- TAB SWITCHING
-- ============================================================

function FL:UpdateJournal()
    if not J or not self.db then return end

    local tab = self.db.journalTab

    J.views.stats:SetShown(
        tab == "session" or tab == "lifetime"
    )
    J.views.sources:SetShown(tab == "sources")
    J.views.efficiency:SetShown(tab == "efficiency")
    J.views.zones:SetShown(tab == "zones")
    J.views.history:SetShown(tab == "history")

    for key, button in pairs(J.tabs) do
        button:SetText(
            key == tab and ("[" .. key:upper() .. "]")
            or key:upper()
        )
    end

    if tab == "sources" then
        UpdateSources()
    elseif tab == "efficiency" then
        UpdateEfficiency()
    elseif tab == "zones" then
        UpdateZones()
    elseif tab == "history" then
        UpdateHistory()
    else
        UpdateStats(tab)
    end
end

function FL:ToggleJournal(force)
    if not J then return end

    if force == true then
        self:UpdateJournal()
        J:Show()
    elseif J:IsShown() then
        J:Hide()
    else
        self:UpdateJournal()
        J:Show()
    end
end

-- ============================================================
-- END Journal.lua v1.3.0
-- ============================================================
