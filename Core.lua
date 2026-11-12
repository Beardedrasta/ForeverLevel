-- ============================================================
-- FOREVER LEVEL v1.3.0
-- Core.lua - COMPLETE REPLACEMENT
-- ============================================================

local addonName, FL = ...

FL.version = "1.3.0"
FL.WHITE = "Interface\\Buttons\\WHITE8X8"
FL.GOLD = { 0.88, 0.71, 0.37 }

FL.order = { "kills", "quests", "level", "time" }

FL.info = {
    kills = {
        label = "KILLS",
        icon = "Interface\\Icons\\Ability_DualWield",
    },
    quests = {
        label = "QUESTS",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
    },
    level = {
        label = "PROGRESS",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
    },
    time = {
        label = "TIME",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
    },
}

FL.defaultPositions = {
    kills = { -112, 67 },
    quests = { 112, 67 },
    level = { -112, 22 },
    time = { 112, 22 },
}

FL.borderPresets = {
    antique = { 0.70, 0.52, 0.25 },
    royal = { 0.88, 0.68, 0.32 },
    bright = { 1.00, 0.82, 0.43 },
}

function FL:Say(message)
    print(
        "|cFFE5BD71Forever Level:|r "
        .. tostring(message)
    )
end

function FL:Safe(value)
    if type(value) ~= "number" then
        return nil
    end

    if issecretvalue and issecretvalue(value) then
        return nil
    end

    return value
end

function FL:Clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

function FL:Comma(value)
    if value == nil then return "--" end

    local s = tostring(math.floor(value + 0.5))
    local n

    repeat
        s, n = s:gsub(
            "^(-?%d+)(%d%d%d)", "%1,%2"
        )
    until n == 0

    return s
end

function FL:Duration(seconds)
    if not seconds or seconds < 0
        or seconds == math.huge then
        return "--"
    end

    seconds = math.floor(seconds + 0.5)

    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60

    if h >= 24 then
        return string.format(
            "%dd %dh", math.floor(h / 24), h % 24
        )
    elseif h > 0 then
        return string.format("%dh %02dm", h, m)
    elseif m > 0 then
        return string.format("%dm %02ds", m, s)
    end

    return string.format("%ds", s)
end

function FL:XPData()
    local level = self:Safe(UnitLevel("player"))
    local xp = self:Safe(UnitXP("player"))
    local maximum = self:Safe(UnitXPMax("player"))

    if xp == nil or not maximum or maximum <= 0 then
        return level, nil, nil, nil
    end

    return level, xp, maximum,
        math.max(0, maximum - xp)
end

function FL:Estimate(remaining, count, total)
    if not remaining or not count or not total
        or count <= 0 or total <= 0 then
        return nil
    end

    return math.ceil(remaining * count / total)
end

function FL:Confidence(count)
    if count < 1 then return "No samples" end
    if count < 5 then return "Low" end
    if count < 15 then return "Developing" end
    if count < 30 then return "Moderate" end
    return "Higher sample count"
end

function FL:NewTotals()
    return {
        gained = 0,
        kills = 0,
        killXP = 0,
        quests = 0,
        questXP = 0,
    }
end

function FL:NewZone()
    local z = self:NewTotals()
    z.seconds = 0
    z.visits = 0
    return z
end

-- ============================================================
-- DATABASE
-- ============================================================

function FL:LoadDatabase()
    if type(ForeverLevelDB) ~= "table" then
        ForeverLevelDB = {}
    end

    local db = ForeverLevelDB
    self.db = db

    db.positions = type(db.positions) == "table"
        and db.positions or {}

    db.hidden = type(db.hidden) == "table"
        and db.hidden or {}

    db.dockPosition =
        type(db.dockPosition) == "table"
        and db.dockPosition or { 0, 0 }

    if db.mode ~= "dock"
        and db.mode ~= "detached" then
        db.mode = db.detached
            and "detached" or "dock"
    end

    db.scale = self:Clamp(
        self:Safe(db.scale) or 1,
        0.70, 1.50
    )

    db.opacity = self:Clamp(
        self:Safe(db.opacity) or 0.97,
        0.50, 1
    )

    db.locked = db.locked == true

    if db.timeMode ~= "session"
        and db.timeMode ~= "recent"
        and db.timeMode ~= "active" then
        db.timeMode = "session"
    end

    if db.killMode ~= "session"
        and db.killMode ~= "recent" then
        db.killMode = "session"
    end

    -- Only two XP bar modes are supported now.
    if db.xpBarMode ~= "current"
        and db.xpBarMode ~= "both" then
        db.xpBarMode = "both"
    end

    if db.activeWindow ~= 60
        and db.activeWindow ~= 90
        and db.activeWindow ~= 120 then
        db.activeWindow = 90
    end

    if not self.borderPresets[db.borderPreset] then
        db.borderPreset = "royal"
    end

    if type(db.lifetime) ~= "table" then
        db.lifetime = self:NewTotals()
    end

    for key in pairs(self:NewTotals()) do
        db.lifetime[key] =
            self:Safe(db.lifetime[key]) or 0
    end

    db.levelHistory =
        type(db.levelHistory) == "table"
        and db.levelHistory or {}

    local level = self:Safe(UnitLevel("player"))

    if type(db.levelStats) ~= "table"
        or db.levelStats.level ~= level then
        db.levelStats = {
            level = level,
            gained = 0,
            kills = 0,
            quests = 0,
        }
    end

    for _, key in ipairs({
        "gained", "kills", "quests",
    }) do
        db.levelStats[key] =
            self:Safe(db.levelStats[key]) or 0
    end

    if not self:Safe(db.dockPosition[1])
        or not self:Safe(db.dockPosition[2]) then
        db.dockPosition = { 0, 0 }
    end

    for _, kind in ipairs(self.order) do
        local pos = db.positions[kind]

        if type(pos) ~= "table"
            or not self:Safe(pos[1])
            or not self:Safe(pos[2]) then
            db.positions[kind] = {
                self.defaultPositions[kind][1],
                self.defaultPositions[kind][2],
            }
        end
    end

    db.zones = type(db.zones) == "table"
        and db.zones or {}

    local validTabs = {
        session = true,
        lifetime = true,
        sources = true,
        efficiency = true,
        zones = true,
        history = true,
    }

    if not validTabs[db.journalTab] then
        db.journalTab = "session"
    end

    if db.sourceScope ~= "session"
        and db.sourceScope ~= "lifetime" then
        db.sourceScope = "session"
    end
end

-- ============================================================
-- BLIZZARD BORDER SYSTEM
-- ============================================================

function FL:GetBorderColor()
    local preset = self.db
        and self.db.borderPreset or "royal"

    local colors = self.borderPresets[preset]
        or self.borderPresets.royal

    return unpack(colors)
end

function FL:Style(frame, opacity, edgeSize)
    edgeSize = edgeSize or 12

    frame:SetBackdrop({
        bgFile =
        "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile =
        "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = edgeSize,
        insets = {
            left = 3,
            right = 3,
            top = 3,
            bottom = 3,
        },
    })

    frame:SetBackdropColor(
        0.075, 0.060, 0.043,
        opacity or 0.97
    )

    frame:SetBackdropBorderColor(
        self:GetBorderColor()
    )
end

function FL:RefreshBorderColors()
    local r, g, b = self:GetBorderColor()

    local function Color(frame)
        if frame and frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(
                r, g, b, 1
            )
        end
    end

    Color(self.dock)
    Color(self.xpBar)
    Color(self.journal)
    Color(self.config)

    if self.rows then
        for _, kind in ipairs(self.order) do
            Color(self.rows[kind])
        end
    end

    if self.journalFrames then
        for _, frame in ipairs(self.journalFrames) do
            Color(frame)
        end
    end
end

-- ============================================================
-- SHARED UI
-- ============================================================

function FL:Text(parent, template)
    return parent:CreateFontString(
        nil, "OVERLAY",
        template or "GameFontNormal"
    )
end

function FL:Button(parent, label, w, h, click)
    local b = CreateFrame(
        "Button", nil, parent,
        "UIPanelButtonTemplate"
    )
    b:SetSize(w, h)
    b:SetText(label)
    b:SetScript("OnClick", click)
    return b
end

function FL:TipLine(label, value)
    GameTooltip:AddDoubleLine(
        label,
        tostring(value == nil and "--" or value),
        0.75, 0.69, 0.57,
        1.00, 0.88, 0.66
    )
end

-- ============================================================
-- STARTUP
-- ============================================================

local startup = CreateFrame("Frame")
startup:RegisterEvent("PLAYER_LOGIN")

startup:SetScript("OnEvent", function(_, event)
    if event ~= "PLAYER_LOGIN" then
        return
    end

    FL:LoadDatabase()
    FL:ResetSession()
    FL:BuildTracker()
    FL:BuildJournal()
    FL:BuildConfig()
    FL:ApplyLayout()
    FL:Refresh()
    FL:RegisterCommands()
    FL:StartTracking()

    FL:Say(
        "v" .. FL.version
        .. " loaded. /fl journal or /fl config."
    )
end)

-- ============================================================
-- END Core.lua v1.3.0
-- ============================================================
