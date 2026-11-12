-- ============================================================
-- FOREVER LEVEL v1.4.0
-- Commands.lua - COMPLETE REPLACEMENT
-- ============================================================

local _, FL = ...

FL.version = "1.4.0"

function FL:PrintStats()
    local _, xp, maximum, remaining = self:XPData()
    local s = self.session
    local kill, quest, other = self:Breakdown(s)
    local efficiency = self:EfficiencyData()

    self:Say("v" .. self.version .. " statistics")

    print(
        "XP: " .. self:Comma(xp)
        .. " / " .. self:Comma(maximum)
        .. " | Remaining: " .. self:Comma(remaining)
    )

    print(
        "Session: " .. self:Comma(s.gained)
        .. " XP | " .. s.kills .. " kills | "
        .. s.quests .. " quests"
    )

    print(
        "Session XP/hr: "
        .. self:Comma(efficiency.sessionRate)
    )
    print(
        "Recent XP/hr: "
        .. self:Comma(efficiency.recentRate)
    )
    print(
        "Active XP/hr: "
        .. self:Comma(efficiency.activeRate)
    )

    print(string.format(
        "Activity: %.1f%% | Window: %ds",
        efficiency.activityPercent,
        efficiency.activityWindow
    ))

    print(
        "Peak 5-minute XP/hr: "
        .. self:Comma(efficiency.peakRate)
    )

    print(
        "Sources: " .. self:Comma(kill)
        .. " kill | " .. self:Comma(quest)
        .. " quest | " .. self:Comma(other)
        .. " unclassified"
    )

    local timer = self:LevelTimingData()
    if timer then
        print(
            "Level " .. tostring(timer.level)
            .. " online time: "
            .. self:Duration(timer.seconds)
        )
    end

    print(
        "Lifetime: "
        .. self:Comma(self.db.lifetime.gained)
        .. " XP | "
        .. self:Comma(self.db.lifetime.kills)
        .. " kills | "
        .. self:Comma(self.db.lifetime.quests)
        .. " quests"
    )

    print(
        "Zones: " .. #self:ZoneRows()
        .. " | Recorded level-ups: "
        .. #self.db.levelHistory
    )
end

function FL:PrintPositions()
    self:Say("Saved position diagnostics")
    local db = self.db

    print(string.format(
        "Mode: %s | Scale: %.2f | Locked: %s",
        db.mode, db.scale, tostring(db.locked)
    ))

    print(string.format(
        "Dock: %.2f, %.2f",
        db.dockPosition[1],
        db.dockPosition[2]
    ))

    for _, kind in ipairs(self.order) do
        local p = db.positions[kind]
        print(string.format(
            "%s: %.2f, %.2f",
            kind, p[1], p[2]
        ))
    end
end

function FL:PrintLevelTiming()
    local timer = self:LevelTimingData()
    if not timer then
        self:Say("Level timer unavailable.")
        return
    end

    self:Say("Persistent level timing")

    print(
        "Current level: " .. tostring(timer.level)
    )
    print(
        "Observed online time: "
        .. self:Duration(timer.seconds)
    )

    if timer.complete then
        print(
            "|cFF80D78CFull level start observed.|r "
            .. "Timing can survive relogs."
        )
    else
        print(
            "|cFFFFCF77Partial level observation.|r "
            .. "A full timing record begins "
            .. "after your next observed level-up."
        )
    end

    print(
        "Offline time is not included. "
        .. "This is online time, including downtime."
    )
end

function FL:HandleCommand(input)
    local cmd, arg = (input or ""):lower():match(
        "^%s*(%S*)%s*(.-)%s*$"
    )

    local db = self.db

    if cmd == "config" or cmd == "options" then
        self:ToggleConfig()
    elseif cmd == "journal" then
        self:ToggleJournal()
    elseif cmd == "sources"
        or cmd == "zones"
        or cmd == "history"
        or cmd == "efficiency" then
        db.journalTab = cmd
        self:ToggleJournal(true)
    elseif cmd == "timing" then
        self:PrintLevelTiming()
    elseif cmd == "activity" then
        if self:SetActivityWindow(arg) then
            self:Say(
                "Activity window: " .. arg .. " seconds"
            )
        else
            self:Say("Use /fl activity 60, 90, or 120.")
        end
    elseif cmd == "xpbar" then
        if arg == "current" or arg == "both" then
            db.xpBarMode = arg
            self:Refresh()
            self:UpdateConfig()

            self:Say(
                "XP bar: "
                .. (arg == "both"
                    and "Current + Rested"
                    or "Current XP")
            )
        else
            self:Say(
                "Use /fl xpbar current or both."
            )
        end
    elseif cmd == "border" then
        if self.borderPresets[arg] then
            db.borderPreset = arg
            self:RefreshBorderColors()
            self:UpdateConfig()
            self:Say("Border preset: " .. arg)
        else
            self:Say(
                "Use /fl border antique, royal or bright."
            )
        end
    elseif cmd == "dock" or cmd == "compact" then
        self:SavePositions()
        db.mode = "dock"
        self:ApplyLayout()
        self:Say("Docked layout enabled.")
    elseif cmd == "detach" then
        self:SavePositions()
        db.mode = "detached"
        self:ApplyLayout()
        self:Say("Detached layout enabled.")
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = cmd == "lock"
        self:UpdateConfig()
        self:Say(
            db.locked and "Panels locked."
            or "Panels unlocked."
        )
    elseif cmd == "show" or cmd == "hide" then
        local hidden = cmd == "hide"

        if arg == "" or arg == "all" then
            for _, kind in ipairs(self.order) do
                db.hidden[kind] = hidden
            end
        elseif self.info[arg] then
            db.hidden[arg] = hidden
        else
            self:Say(
                "Use kills, quests, level, time, or all."
            )
            return
        end

        self:ApplyLayout()
    elseif cmd == "rate" then
        if arg == "session"
            or arg == "recent"
            or arg == "active" then
            db.timeMode = arg
            self:Refresh()
            self:UpdateConfig()
            self:Say("Time mode: " .. arg)
        else
            self:Say(
                "Use /fl rate session/recent/active."
            )
        end
    elseif cmd == "kills" then
        if arg == "session" or arg == "recent" then
            db.killMode = arg
            self:Refresh()
            self:UpdateConfig()
            self:Say("Kill mode: " .. arg)
        else
            self:Say(
                "Use /fl kills session or recent."
            )
        end
    elseif cmd == "reset" then
        self:ResetSession()
        self:Refresh()
        self:Say(
            "Session reset; level timing and "
            .. "lifetime statistics preserved."
        )
    elseif cmd == "layout" then
        db.dockPosition = { 0, 0 }

        for _, kind in ipairs(self.order) do
            db.positions[kind] = {
                self.defaultPositions[kind][1],
                self.defaultPositions[kind][2],
            }
        end

        self:ApplyLayout()
        self:Say("Panel positions restored.")
    elseif cmd == "pos" then
        self:SavePositions()
        self:PrintPositions()
    elseif cmd == "stats" then
        self:PrintStats()
    elseif cmd == "status" then
        local _, xp, maximum = self:XPData()

        self:Say(
            "v" .. self.version
            .. " | " .. db.mode
            .. " | XP " .. tostring(xp)
            .. "/" .. tostring(maximum)
            .. " | Rate " .. db.timeMode
            .. " | Bar " .. db.xpBarMode
        )
    else
        self:Say("Available commands:")
        print("/fl config - Configuration")
        print("/fl journal - Leveling Journal")
        print("/fl timing - Persistent level timer")
        print("/fl efficiency - Efficiency tab")
        print("/fl sources - XP source breakdown")
        print("/fl zones - Zone analytics")
        print("/fl history - Level-up history")
        print("/fl activity 60/90/120")
        print("/fl rate session/recent/active")
        print("/fl xpbar current/both")
        print("/fl border antique/royal/bright")
        print("/fl dock or detach")
        print("/fl lock or unlock")
        print("/fl show/hide kills/quests/level/time/all")
        print("/fl kills session/recent")
        print("/fl stats - Statistics")
        print("/fl reset - Reset session")
        print("/fl layout - Reset positions")
        print("/fl pos - Position diagnostics")
        print("/fl status - Version diagnostics")
    end
end

function FL:RegisterCommands()
    SLASH_FOREVERLEVEL1 = "/fl"
    SLASH_FOREVERLEVEL2 = "/foreverlevel"

    SlashCmdList.FOREVERLEVEL = function(input)
        FL:HandleCommand(input)
    end
end

-- ============================================================
-- END Commands.lua v1.4.0
-- ============================================================
