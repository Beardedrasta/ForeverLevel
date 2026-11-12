-- ============================================================
-- FOREVER LEVEL v1.4.0
-- Tracking.lua - COMPLETE REPLACEMENT
--
-- Persistent online level timing
-- Cross-login level history
-- XP baseline and level-up reconciliation
-- Zone analytics, active time, recent XP,
-- kill and quest tracking
-- ============================================================

local _, FL = ...
FL.tracking = FL.tracking or {}

local RECENT_WINDOW = 300
local ZONE_MIN_SECONDS = 120
local ZONE_MIN_XP = 100

local function AddSample(list, value, limit)
    table.insert(list, value)
    while #list > limit do
        table.remove(list, 1)
    end
end

local function EnsureZone(data, name)
    if type(data[name]) ~= "table" then
        data[name] = FL:NewZone()
    end

    local z = data[name]
    for _, key in ipairs({
        "gained", "kills", "killXP",
        "quests", "questXP", "seconds", "visits"
    }) do
        z[key] = FL:Safe(z[key]) or 0
    end
    return z
end

-- ============================================================
-- SETTINGS
-- ============================================================

function FL:InitializeTrackingSettings()
    local db = self.db

    if db.timeMode ~= "session"
        and db.timeMode ~= "recent"
        and db.timeMode ~= "active" then
        db.timeMode = "session"
    end

    if db.xpBarMode ~= "current"
        and db.xpBarMode ~= "both" then
        db.xpBarMode = "both"
    end

    if db.activeWindow ~= 60
        and db.activeWindow ~= 90
        and db.activeWindow ~= 120 then
        db.activeWindow = 90
    end
end

-- ============================================================
-- PERSISTENT LEVEL TIMER
-- ============================================================

function FL:InitializeLevelTimer()
    local level = self:Safe(UnitLevel("player"))
    local saved = self.db.levelTiming

    if type(saved) ~= "table"
        or saved.level ~= level then
        -- We did not observe this level's beginning.
        -- Start measuring, but do not label it
        -- a complete level duration.
        saved = {
            level = level,
            seconds = 0,
            startedFromLevelUp = false,
        }
        self.db.levelTiming = saved
    end

    saved.seconds = math.max(
        0, self:Safe(saved.seconds) or 0
    )
    saved.startedFromLevelUp =
        saved.startedFromLevelUp == true

    if self.session then
        self.session.levelTick = GetTime()
    end
end

function FL:FlushLevelTime()
    local s = self.session
    local timer = self.db.levelTiming

    if not s or not timer then return end

    local now = GetTime()
    local previous = s.levelTick

    if not previous then
        s.levelTick = now
        return
    end

    local elapsed = now - previous

    if elapsed > 0 then
        -- GetTime is session-local. The saved total
        -- is accumulated explicitly before logout.
        timer.seconds =
            (timer.seconds or 0) + elapsed
    end

    s.levelTick = now
end

function FL:LevelTimingData()
    self:FlushLevelTime()

    local timer = self.db.levelTiming
    if not timer then return nil end

    return {
        level = timer.level,
        seconds = timer.seconds or 0,
        complete = timer.startedFromLevelUp == true,
    }
end

-- ============================================================
-- ZONE TIMER
-- ============================================================

function FL:GetZoneName()
    local name = GetZoneText and GetZoneText()
    if type(name) ~= "string" or name == "" then
        return "Unknown Zone"
    end
    return name
end

function FL:FlushZoneTime()
    local s = self.session
    if not s or not s.zone or not s.zoneStart then
        return
    end

    local now = GetTime()
    local elapsed = math.max(0, now - s.zoneStart)
    if elapsed <= 0 then return end

    local zs = EnsureZone(s.zones, s.zone)
    local zl = EnsureZone(self.db.zones, s.zone)

    zs.seconds = zs.seconds + elapsed
    zl.seconds = zl.seconds + elapsed
    s.zoneStart = now
end

function FL:ChangeZone(force)
    local s = self.session
    if not s then return end

    local name = self:GetZoneName()
    if not force and s.zone == name then return end

    self:FlushZoneTime()

    if name ~= s.zone or not s.zone then
        local zs = EnsureZone(s.zones, name)
        local zl = EnsureZone(self.db.zones, name)

        zs.visits = zs.visits + 1
        zl.visits = zl.visits + 1
    end

    s.zone = name
    s.zoneStart = GetTime()
end

function FL:ActiveZone()
    if not self.session.zone then
        self:ChangeZone(true)
    end

    local name = self.session.zone
    return EnsureZone(self.session.zones, name),
        EnsureZone(self.db.zones, name)
end

-- ============================================================
-- SESSION
-- ============================================================

function FL:ResetSession()
    if self.session then
        self:FlushZoneTime()
        self:FlushLevelTime()
    end

    self:InitializeTrackingSettings()

    local level, xp, maximum = self:XPData()
    local now = GetTime()
    local s = self:NewTotals()

    self.session = s

    s.started = now
    s.lastLevel = level
    s.lastXP = xp
    s.lastMax = maximum

    s.recent = {}
    s.recentKills = {}

    s.zones = {}
    s.zone = nil
    s.zoneStart = nil

    s.activeSeconds = 0
    s.activityLastTick = now
    s.lastGainTime = nil

    s.peakFiveMinuteRate = nil
    s.peakFiveMinuteTime = nil

    -- Preserve cross-login level timing, but
    -- start a fresh local elapsed-time anchor.
    self:InitializeLevelTimer()
    self:ChangeZone(true)
end

-- ============================================================
-- ACTIVITY ESTIMATION
-- ============================================================

function FL:TickActivity()
    local s = self.session
    if not s then return end

    local now = GetTime()
    local previous = s.activityLastTick or now

    if now < previous then
        s.activityLastTick = now
        return
    end

    if s.lastGainTime then
        local activeUntil =
            s.lastGainTime + self.db.activeWindow

        local first = math.max(
            previous, s.lastGainTime
        )
        local last = math.min(now, activeUntil)

        if last > first then
            s.activeSeconds =
                s.activeSeconds + last - first
        end
    end

    s.activityLastTick = now
end

function FL:ActiveSeconds()
    self:TickActivity()
    return self.session.activeSeconds or 0
end

function FL:ActiveRate()
    local seconds = self:ActiveSeconds()
    if seconds < 30 or self.session.gained <= 0 then
        return nil
    end

    return self.session.gained * 3600 / seconds
end

function FL:ActivityPercent()
    local elapsed = GetTime() - self.session.started
    if elapsed <= 0 then return 0 end

    return self:Clamp(
        self:ActiveSeconds() * 100 / elapsed,
        0, 100
    )
end

function FL:SetActivityWindow(seconds)
    seconds = tonumber(seconds)

    if seconds ~= 60
        and seconds ~= 90
        and seconds ~= 120 then
        return false
    end

    self:TickActivity()
    self.db.activeWindow = seconds
    self:Refresh()

    if self.UpdateConfig then
        self:UpdateConfig()
    end

    return true
end

-- ============================================================
-- XP/HOUR
-- ============================================================

function FL:PruneRecent()
    local cutoff = GetTime() - RECENT_WINDOW
    local recent = self.session.recent

    for i = #recent, 1, -1 do
        if recent[i].time <= cutoff then
            table.remove(recent, i)
        end
    end
end

function FL:SessionRate()
    local elapsed = GetTime() - self.session.started
    if elapsed < 30 or self.session.gained <= 0 then
        return nil
    end
    return self.session.gained * 3600 / elapsed
end

function FL:RecentRate()
    self:PruneRecent()

    local total = 0
    for _, entry in ipairs(self.session.recent) do
        total = total + entry.xp
    end

    if total <= 0 then return nil end

    local elapsed = GetTime() - self.session.started
    if elapsed < 60 then return nil end

    return total * 3600
        / math.min(elapsed, RECENT_WINDOW)
end

function FL:SelectedRate()
    if self.db.timeMode == "active" then
        return self:ActiveRate()
    elseif self.db.timeMode == "recent" then
        return self:RecentRate()
    end
    return self:SessionRate()
end

function FL:UpdatePeakRate()
    local s = self.session
    if GetTime() - s.started < RECENT_WINDOW then
        return
    end

    self:PruneRecent()

    local total = 0
    for _, entry in ipairs(s.recent) do
        total = total + entry.xp
    end

    local rate = total * 12

    if rate > 0 and (
            not s.peakFiveMinuteRate
            or rate > s.peakFiveMinuteRate
        ) then
        s.peakFiveMinuteRate = rate
        s.peakFiveMinuteTime = GetTime()
    end
end

function FL:EfficiencyData()
    local s = self.session

    return {
        elapsed = GetTime() - s.started,
        active = self:ActiveSeconds(),
        activityPercent = self:ActivityPercent(),
        totalXP = s.gained,
        sessionRate = self:SessionRate(),
        recentRate = self:RecentRate(),
        activeRate = self:ActiveRate(),
        peakRate = s.peakFiveMinuteRate,
        activityWindow = self.db.activeWindow,
    }
end

-- ============================================================
-- KILL ESTIMATES AND XP SOURCES
-- ============================================================

function FL:KillAverage()
    local s = self.session

    if self.db.killMode == "recent" then
        local count = #s.recentKills
        if count == 0 then return nil, 0 end

        local sum = 0
        for _, value in ipairs(s.recentKills) do
            sum = sum + value
        end

        return sum / count, count
    end

    if s.kills <= 0 then return nil, 0 end
    return s.killXP / s.kills, s.kills
end

function FL:KillEstimate(remaining)
    local average = self:KillAverage()

    if remaining == nil
        or not average or average <= 0 then
        return nil
    end

    return math.ceil(remaining / average)
end

function FL:Breakdown(totals)
    local gained = math.max(0, totals.gained or 0)
    local kill = math.min(
        gained, math.max(0, totals.killXP or 0)
    )
    local quest = math.min(
        gained - kill,
        math.max(0, totals.questXP or 0)
    )

    return kill, quest, gained - kill - quest, gained
end

-- ============================================================
-- ZONE PERFORMANCE
-- ============================================================

function FL:ZoneRows()
    self:FlushZoneTime()

    local entries = {}

    for name, zone in pairs(self.db.zones) do
        if type(zone) == "table" then
            local xp = self:Safe(zone.gained) or 0
            local seconds =
                self:Safe(zone.seconds) or 0

            local rate

            if seconds >= ZONE_MIN_SECONDS
                and xp >= ZONE_MIN_XP then
                rate = xp * 3600 / seconds
            end

            table.insert(entries, {
                name = name,
                data = zone,
                rate = rate,
            })
        end
    end

    table.sort(entries, function(a, b)
        if a.rate and b.rate then
            if a.rate ~= b.rate then
                return a.rate > b.rate
            end
        elseif a.rate then
            return true
        elseif b.rate then
            return false
        end

        local ax = a.data.gained or 0
        local bx = b.data.gained or 0

        if ax ~= bx then return ax > bx end
        return a.name < b.name
    end)

    return entries
end

function FL:BestZone()
    for _, entry in ipairs(self:ZoneRows()) do
        if entry.rate then
            return entry
        end
    end
    return nil
end

-- ============================================================
-- LEVEL HISTORY - PERSISTENT ONLINE TIME
-- ============================================================

function FL:RecordLevelUp(oldLevel, newLevel)
    if not oldLevel or not newLevel
        or newLevel <= oldLevel then
        return
    end

    local s = self.session

    -- Time is collected before the timer changes
    -- to the new level.
    self:FlushLevelTime()

    local timer = self.db.levelTiming
    local stats = self.db.levelStats

    local seconds = timer
        and timer.level == oldLevel
        and timer.seconds or nil

    local complete = timer
        and timer.level == oldLevel
        and timer.startedFromLevelUp == true
        and seconds ~= nil
        and newLevel == oldLevel + 1

    -- Older records remain intact.
    table.insert(self.db.levelHistory, {
        from = oldLevel,
        to = newLevel,
        time = time(),
        observedXP = stats.gained or 0,
        kills = stats.kills or 0,
        quests = stats.quests or 0,
        levelSeconds = seconds,
        completeTiming = complete or false,
    })

    while #self.db.levelHistory > 100 do
        table.remove(self.db.levelHistory, 1)
    end

    -- The new level begins now, even if the
    -- player logs out before reaching the next.
    self.db.levelTiming = {
        level = newLevel,
        seconds = 0,
        startedFromLevelUp =
            newLevel == oldLevel + 1,
    }

    s.levelTick = GetTime()

    self.db.levelStats = {
        level = newLevel,
        gained = 0,
        kills = 0,
        quests = 0,
    }

    self:Say("Level " .. newLevel .. " reached!")
end

-- ============================================================
-- OBSERVED XP DELTAS
-- ============================================================

function FL:TrackXP()
    local level, xp, maximum = self:XPData()
    if xp == nil or not level then return end

    local s = self.session
    local oldLevel = s.lastLevel
    local oldXP = s.lastXP
    local gained = 0
    local nextLevelXP = 0
    local previousLevelXP = 0

    if oldLevel and oldXP ~= nil then
        if level == oldLevel then
            -- Negative XP changes are not XP earned.
            gained = math.max(0, xp - oldXP)
        elseif level == oldLevel + 1
            and s.lastMax then
            previousLevelXP = math.max(
                0, s.lastMax - oldXP
            )
            nextLevelXP = math.max(0, xp)
            gained = previousLevelXP + nextLevelXP
        end
    end

    if gained > 0 then
        self:TickActivity()
        s.lastGainTime = GetTime()

        s.gained = s.gained + gained
        self.db.lifetime.gained =
            self.db.lifetime.gained + gained

        AddSample(s.recent, {
            time = GetTime(),
            xp = gained,
        }, 2000)

        local zs, zl = self:ActiveZone()
        zs.gained = zs.gained + gained
        zl.gained = zl.gained + gained

        if level == oldLevel then
            self.db.levelStats.gained =
                self.db.levelStats.gained + gained
        else
            self.db.levelStats.gained =
                self.db.levelStats.gained
                + previousLevelXP
        end

        self:UpdatePeakRate()
    end

    if oldLevel and level > oldLevel then
        self:RecordLevelUp(oldLevel, level)

        if level == oldLevel + 1 then
            -- Credit overflow XP to the new level.
            self.db.levelStats.gained =
                nextLevelXP
        end
    elseif oldLevel and level < oldLevel then
        -- Level loss/character correction:
        -- reestablish the level timer without
        -- inventing a level-up record.
        self:FlushLevelTime()

        self.db.levelTiming = {
            level = level,
            seconds = 0,
            startedFromLevelUp = false,
        }
        s.levelTick = GetTime()

        self.db.levelStats = {
            level = level,
            gained = 0,
            kills = 0,
            quests = 0,
        }
    end

    -- Always update the baseline, including when
    -- XP decreased or an event was duplicated.
    s.lastLevel = level
    s.lastXP = xp
    s.lastMax = maximum

    self:Refresh()
end

-- ============================================================
-- KILL / QUEST EVENTS
-- ============================================================

function FL:TrackKill(message)
    if type(message) ~= "string" then return end
    if issecretvalue and issecretvalue(message) then
        return
    end

    -- Preserve parser verified in earlier builds.
    local lower = message:lower()

    if not lower:find(" dies", 1, true) then
        return
    end

    local amount = lower:match(
        "you gain ([%d,]+) experience"
    )

    if amount then
        amount = tonumber((amount:gsub(",", "")))
    end

    if not amount or amount <= 0 then return end

    local s = self.session
    local lifetime = self.db.lifetime

    s.kills = s.kills + 1
    s.killXP = s.killXP + amount

    lifetime.kills = lifetime.kills + 1
    lifetime.killXP = lifetime.killXP + amount

    self.db.levelStats.kills =
        self.db.levelStats.kills + 1

    AddSample(s.recentKills, amount, 20)

    local zs, zl = self:ActiveZone()

    zs.kills = zs.kills + 1
    zs.killXP = zs.killXP + amount

    zl.kills = zl.kills + 1
    zl.killXP = zl.killXP + amount

    self:Refresh()
end

function FL:TrackQuest(reward)
    reward = self:Safe(reward)
    if not reward or reward <= 0 then return end

    local s = self.session
    local lifetime = self.db.lifetime

    s.quests = s.quests + 1
    s.questXP = s.questXP + reward

    lifetime.quests = lifetime.quests + 1
    lifetime.questXP = lifetime.questXP + reward

    self.db.levelStats.quests =
        self.db.levelStats.quests + 1

    local zs, zl = self:ActiveZone()

    zs.quests = zs.quests + 1
    zs.questXP = zs.questXP + reward

    zl.quests = zl.quests + 1
    zl.questXP = zl.questXP + reward

    self:Refresh()
end

-- ============================================================
-- EVENTS AND PERIODIC UPDATES
-- ============================================================

function FL:StartTracking()
    local frame = CreateFrame("Frame")
    self.trackingFrame = frame

    for _, event in ipairs({
        "PLAYER_XP_UPDATE",
        "PLAYER_LEVEL_UP",
        "UPDATE_EXHAUSTION",
        "QUEST_TURNED_IN",
        "CHAT_MSG_COMBAT_XP_GAIN",
        "ZONE_CHANGED_NEW_AREA",
        "ZONE_CHANGED",
        "PLAYER_LOGOUT",
    }) do
        frame:RegisterEvent(event)
    end

    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_XP_UPDATE" then
            FL:TrackXP()
        elseif event == "PLAYER_LEVEL_UP" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    FL:TrackXP()
                end)
            else
                FL:TrackXP()
            end
        elseif event == "UPDATE_EXHAUSTION" then
            FL:Refresh()
        elseif event == "QUEST_TURNED_IN" then
            local _, reward = ...
            FL:TrackQuest(reward)
        elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
            FL:TrackKill(...)
        elseif event == "ZONE_CHANGED"
            or event == "ZONE_CHANGED_NEW_AREA" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    FL:ChangeZone(false)
                end)
            else
                FL:ChangeZone(false)
            end
        elseif event == "PLAYER_LOGOUT" then
            FL:TickActivity()
            FL:FlushZoneTime()
            FL:FlushLevelTime()
            FL:SavePositions()
        end
    end)

    local tick = 0

    frame:SetScript("OnUpdate", function(_, elapsed)
        tick = tick + elapsed

        if tick >= 2 then
            tick = 0

            FL:TickActivity()
            FL:PruneRecent()
            FL:UpdatePeakRate()
            FL:FlushZoneTime()
            FL:FlushLevelTime()
            FL:Refresh()
        end
    end)
end

-- ============================================================
-- END Tracking.lua v1.4.0
-- ============================================================
