-- ============================================================
-- FOREVER LEVEL v1.2.0
-- Tracker.lua - COMPLETE REPLACEMENT
-- ============================================================

local _, FL = ...

FL.version = "1.2.0"

local dock, xpBar, xpInside
local xpFill, restedFill
local rows = {}

FL.rows = rows

local DOCK_WIDTH = 229
local HEADER = 38
local FOOTER = 26
local ROW_STEP = 42
local ROW_WIDTH = 188
local ROW_HEIGHT = 38

local function VisibleCount()
    local count = 0

    for _, kind in ipairs(FL.order) do
        if not FL.db.hidden[kind] then
            count = count + 1
        end
    end

    return count
end

local function DockHeight(count)
    return HEADER + count * ROW_STEP + FOOTER
end

-- ============================================================
-- PRECISE MOVEMENT
-- ============================================================

function FL:ReadPosition(frame)
    if not frame then return nil, nil end

    local x, y = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()

    local fs = frame:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()

    if not x or not y or not ux or not uy
        or not fs or fs <= 0
        or not us or us <= 0 then
        return nil, nil
    end

    return ((x * fs) - (ux * us)) / us,
        ((y * fs) - (uy * us)) / us
end

function FL:RestorePosition(frame, x, y)
    local fs = frame:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()

    if not fs or fs <= 0 or not us
        or us <= 0 then
        return
    end

    local factor = us / fs

    frame:ClearAllPoints()
    frame:SetPoint(
        "CENTER", UIParent, "CENTER",
        (x or 0) * factor,
        (y or 0) * factor
    )
end

function FL:SaveDock()
    if not dock or not self.db then return end

    local x, y = self:ReadPosition(dock)

    if x and y then
        self.db.dockPosition = { x, y }
    end

    -- No reanchoring on drag release.
end

function FL:SavePanel(kind)
    if not self.db or
        self.db.mode ~= "detached" then
        return
    end

    local frame = rows[kind]
    if not frame then return end

    local x, y = self:ReadPosition(frame)

    if x and y then
        self.db.positions[kind] = { x, y }
    end
end

function FL:SavePositions()
    if not self.db then return end

    if self.db.mode == "dock" then
        self:SaveDock()
    else
        for _, kind in ipairs(self.order) do
            self:SavePanel(kind)
        end
    end
end

-- ============================================================
-- HOVER TOOLTIPS
-- ============================================================

function FL:TrackerTooltip(kind, owner)
    local level, xp, maximum, remaining =
        self:XPData()

    local s = self.session
    local lifetime = self.db.lifetime

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(
        "Forever Level | " .. self.info[kind].label,
        unpack(self.GOLD)
    )
    GameTooltip:AddLine(" ")

    self:TipLine("Current level", level)
    self:TipLine(
        "XP remaining", self:Comma(remaining)
    )

    if kind == "kills" then
        local average, count = self:KillAverage()

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "KILL PROJECTION", unpack(self.GOLD)
        )

        self:TipLine(
            "Estimated kills",
            self:KillEstimate(remaining) or "Calculating"
        )
        self:TipLine(
            "Average kill XP", self:Comma(average)
        )
        self:TipLine("Samples used", count)
        self:TipLine(
            "Confidence", self:Confidence(count)
        )
        self:TipLine(
            "Estimate mode",
            self.db.killMode == "recent"
            and "Last 20 kills" or "Full session"
        )

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("SESSION", unpack(self.GOLD))
        self:TipLine("Kills", s.kills)
        self:TipLine("Kill XP", self:Comma(s.killXP))

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("LIFETIME", unpack(self.GOLD))
        self:TipLine(
            "Recorded kills", self:Comma(lifetime.kills)
        )
    elseif kind == "quests" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "QUEST PROJECTION", unpack(self.GOLD)
        )

        self:TipLine(
            "Estimated quests",
            self:Estimate(
                remaining, s.quests, s.questXP
            ) or "Calculating"
        )
        self:TipLine(
            "Average quest XP",
            s.quests > 0
            and self:Comma(s.questXP / s.quests)
            or "--"
        )
        self:TipLine(
            "Confidence", self:Confidence(s.quests)
        )

        GameTooltip:AddLine(" ")
        self:TipLine("Session quests", s.quests)
        self:TipLine(
            "Session quest XP", self:Comma(s.questXP)
        )
        self:TipLine(
            "Lifetime quests", self:Comma(lifetime.quests)
        )
    elseif kind == "time" then
        local rate = self:SelectedRate()
        local eta = rate and rate > 0 and remaining
            and remaining * 3600 / rate or nil

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "LEVELING SPEED", unpack(self.GOLD)
        )

        self:TipLine(
            "Session duration",
            self:Duration(GetTime() - s.started)
        )
        self:TipLine(
            "Estimated active time",
            self:Duration(self:ActiveSeconds())
        )
        self:TipLine(
            "Session XP", self:Comma(s.gained)
        )
        self:TipLine(
            "Full session XP/hour",
            self:Comma(self:SessionRate())
        )
        self:TipLine(
            "Recent XP/hour",
            self:Comma(self:RecentRate())
        )
        self:TipLine(
            "Active XP/hour",
            self:Comma(self:ActiveRate())
        )
        self:TipLine(
            "Projection mode",
            self.db.timeMode == "active"
            and "Active leveling"
            or self.db.timeMode == "recent"
            and "Recent 5 minutes"
            or "Full session"
        )
        self:TipLine(
            "Estimated time remaining",
            eta and self:Duration(eta)
            or "Calculating"
        )

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "Active = up to 90 seconds after XP gains.",
            0.65, 0.65, 0.65, true
        )
    else
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(
            "LEVEL PROGRESS", unpack(self.GOLD)
        )

        self:TipLine("Current XP", self:Comma(xp))
        self:TipLine("Required XP", self:Comma(maximum))
        self:TipLine("Remaining XP", self:Comma(remaining))

        local rested = GetXPExhaustion
            and self:Safe(GetXPExhaustion()) or 0

        self:TipLine(
            "Available rested XP",
            self:Comma(rested)
        )

        self:TipLine(
            "XP bar mode",
            self.db.xpBarMode == "current"
            and "Current XP"
            or self.db.xpBarMode == "rested"
            and "Rested XP only"
            or "Current + Rested"
        )

        self:TipLine(
            "Observed XP this level",
            self:Comma(self.db.levelStats.gained)
        )
        self:TipLine(
            "Recorded level-ups",
            #self.db.levelHistory
        )
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(
        "Current zone: " .. self:GetZoneName(),
        0.80, 0.70, 0.52
    )
    GameTooltip:AddLine(
        "Use /fl journal for full statistics.",
        0.65, 0.65, 0.65
    )
    GameTooltip:Show()
end

-- ============================================================
-- VERTICAL XP BAR
-- ============================================================

local function BuildXPStrip()
    xpBar = CreateFrame(
        "Frame", nil, dock, "BackdropTemplate"
    )

    FL.xpBar = xpBar

    xpBar:SetSize(16, 166)
    xpBar:SetPoint(
        "TOPLEFT", dock, "TOPLEFT", 8, -39
    )
    xpBar:SetFrameLevel(dock:GetFrameLevel() + 2)

    FL:Style(xpBar, 0.98, 10)

    xpInside = CreateFrame("Frame", nil, xpBar)

    xpInside:SetPoint(
        "TOPLEFT", xpBar, "TOPLEFT", 4, -4
    )
    xpInside:SetPoint(
        "BOTTOMRIGHT", xpBar, "BOTTOMRIGHT", -4, 4
    )
    xpInside:SetClipsChildren(true)

    -- Gold current XP.
    xpFill = xpInside:CreateTexture(
        nil, "ARTWORK", nil, 1
    )
    xpFill:SetTexture(FL.WHITE)
    xpFill:SetVertexColor(0.93, 0.70, 0.25, 1)
    xpFill:SetPoint("BOTTOMLEFT", xpInside)
    xpFill:SetPoint("BOTTOMRIGHT", xpInside)
    xpFill:SetHeight(1)

    -- Blue rested XP segment.
    restedFill = xpInside:CreateTexture(
        nil, "ARTWORK", nil, 0
    )
    restedFill:SetTexture(FL.WHITE)
    restedFill:SetVertexColor(0.27, 0.45, 0.92, 0.90)
    restedFill:SetHeight(1)

    xpBar:EnableMouse(true)

    xpBar:SetScript("OnEnter", function(self)
        FL:TrackerTooltip("level", self)
    end)
    xpBar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    xpBar:RegisterForDrag("LeftButton")

    xpBar:SetScript("OnDragStart", function(self)
        self.dragActive = false

        if FL.db.locked or FL.db.mode ~= "dock" then
            return
        end

        self.dragActive = true
        dock:StartMoving()
    end)

    xpBar:SetScript("OnDragStop", function(self)
        if not self.dragActive then return end

        self.dragActive = false
        dock:StopMovingOrSizing()
        FL:SaveDock()
    end)
end

-- ============================================================
-- MAIN DOCK
-- ============================================================

local function BuildDock()
    dock = CreateFrame(
        "Frame", "ForeverLevelDock",
        UIParent, "BackdropTemplate"
    )

    FL.dock = dock

    dock:SetSize(DOCK_WIDTH, DockHeight(4))
    dock:SetScale(FL.db.scale)

    FL:RestorePosition(
        dock,
        FL.db.dockPosition[1],
        FL.db.dockPosition[2]
    )

    dock:SetFrameStrata("MEDIUM")
    dock:SetClampedToScreen(true)
    dock:SetMovable(true)
    dock:EnableMouse(true)
    dock:RegisterForDrag("LeftButton")

    FL:Style(dock, FL.db.opacity, 16)

    dock:SetScript("OnDragStart", function(self)
        self.dragActive = false

        if FL.db.locked then return end

        self.dragActive = true
        self:StartMoving()
    end)

    dock:SetScript("OnDragStop", function(self)
        if not self.dragActive then return end

        self.dragActive = false
        self:StopMovingOrSizing()
        FL:SaveDock()
    end)

    local heading = FL:Text(
        dock, "GameFontNormalSmall"
    )
    heading:SetPoint(
        "TOPLEFT", dock, "TOPLEFT", 12, -11
    )
    heading:SetText("FOREVER  |  LEVEL")
    heading:SetTextColor(unpack(FL.GOLD))

    local footer = FL:Text(
        dock, "GameFontHighlightSmall"
    )
    footer:SetPoint(
        "BOTTOM", dock, "BOTTOM", 0, 10
    )
    footer:SetText("/FL JOURNAL  |  /FL CONFIG")
    footer:SetTextColor(0.68, 0.60, 0.47)

    BuildXPStrip()
end

-- ============================================================
-- INFORMATION BOXES
-- ============================================================

local function BuildRow(kind)
    local frame = CreateFrame(
        "Frame", "ForeverLevelRow_" .. kind,
        UIParent, "BackdropTemplate"
    )

    frame:SetSize(ROW_WIDTH, ROW_HEIGHT)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    FL:Style(frame, FL.db.opacity, 12)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(23, 23)
    icon:SetPoint("LEFT", frame, "LEFT", 9, 0)
    icon:SetTexture(FL.info[kind].icon)

    local title = FL:Text(
        frame, "GameFontNormalSmall"
    )
    title:SetPoint(
        "TOPLEFT", frame, "TOPLEFT", 39, -7
    )
    title:SetText(FL.info[kind].label)
    title:SetTextColor(0.87, 0.72, 0.43)

    local sub = FL:Text(
        frame, "GameFontHighlightSmall"
    )
    sub:SetPoint(
        "BOTTOMLEFT", frame, "BOTTOMLEFT", 39, 7
    )
    sub:SetTextColor(0.65, 0.61, 0.52)

    local value = FL:Text(
        frame, "GameFontHighlightLarge"
    )
    value:SetPoint(
        "RIGHT", frame, "RIGHT", -9, -1
    )
    value:SetWidth(99)
    value:SetJustifyH("RIGHT")
    value:SetTextColor(0.98, 0.91, 0.76)

    frame.value = value
    frame.sub = sub

    if kind == "level" then
        local track = frame:CreateTexture(
            nil, "BACKGROUND"
        )
        track:SetTexture(FL.WHITE)
        track:SetVertexColor(0.20, 0.17, 0.12)
        track:SetPoint(
            "BOTTOMLEFT", frame, "BOTTOMLEFT", 39, 5
        )
        track:SetSize(138, 2)

        local fill = frame:CreateTexture(nil, "ARTWORK")
        fill:SetTexture(FL.WHITE)
        fill:SetVertexColor(0.88, 0.66, 0.29)
        fill:SetPoint("BOTTOMLEFT", track)
        fill:SetSize(1, 2)

        frame.progress = fill
    end

    frame:SetScript("OnEnter", function(self)
        FL:TrackerTooltip(kind, self)
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame:SetScript("OnDragStart", function(self)
        self.dragActive = false

        if FL.db.locked then return end

        self.dragActive = true

        if FL.db.mode == "detached" then
            self:StartMoving()
        else
            dock:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        if not self.dragActive then return end

        self.dragActive = false

        if FL.db.mode == "detached" then
            self:StopMovingOrSizing()
            FL:SavePanel(kind)
        else
            dock:StopMovingOrSizing()
            FL:SaveDock()
        end
    end)

    rows[kind] = frame
end

function FL:BuildTracker()
    BuildDock()

    for _, kind in ipairs(self.order) do
        BuildRow(kind)
    end
end

-- ============================================================
-- ADAPTIVE LAYOUT
-- ============================================================

function FL:ApplyLayout()
    if not self.db or not dock then return end

    local detached = self.db.mode == "detached"
    local visible = VisibleCount()

    dock.dragActive = false
    xpBar.dragActive = false

    for _, kind in ipairs(self.order) do
        local frame = rows[kind]

        frame.dragActive = false
        frame:Hide()
        frame:SetParent(UIParent)
        frame:ClearAllPoints()
    end

    dock:SetScale(self.db.scale)
    dock:SetSize(DOCK_WIDTH, DockHeight(visible))

    self:RestorePosition(
        dock,
        self.db.dockPosition[1],
        self.db.dockPosition[2]
    )

    if visible == 0 then
        xpBar:Hide()
    else
        xpBar:SetHeight(
            math.max(18, visible * ROW_STEP - 2)
        )
        xpBar:Show()
    end

    local visibleIndex = 0

    for _, kind in ipairs(self.order) do
        local frame = rows[kind]
        local hidden = self.db.hidden[kind]

        if detached then
            local p = self.db.positions[kind]
                or self.defaultPositions[kind]

            frame:SetScale(self.db.scale)
            self:RestorePosition(
                frame, p[1], p[2]
            )
            frame:SetFrameStrata("MEDIUM")
        else
            frame:SetScale(1)
            frame:SetParent(dock)
            frame:SetFrameLevel(
                dock:GetFrameLevel() + 4
            )

            if not hidden then
                frame:SetPoint(
                    "TOPLEFT", dock, "TOPLEFT",
                    31, -38 - visibleIndex * ROW_STEP
                )

                visibleIndex = visibleIndex + 1
            end
        end

        frame:SetShown(not hidden)
    end

    dock:SetShown(not detached)

    self.visibleCount = visible

    self:Style(dock, self.db.opacity, 16)

    for _, kind in ipairs(self.order) do
        self:Style(rows[kind], self.db.opacity, 12)
    end

    if self.RefreshBorderColors then
        self:RefreshBorderColors()
    end

    self:Refresh()

    if self.UpdateConfig then
        self:UpdateConfig()
    end
end

-- ============================================================
-- REFRESH XP STRIP
-- ============================================================

function FL:UpdateXPStrip(pct, xp, maximum)
    local mode = self.db.xpBarMode or "both"

    local height = xpInside:GetHeight()

    if not height or height < 1 then
        height = math.max(
            10, (self.visibleCount or 4) * ROW_STEP - 10
        )
    end

    local rested = GetXPExhaustion
        and self:Safe(GetXPExhaustion()) or 0

    local restedPct = pct

    if xp ~= nil and maximum and maximum > 0 then
        restedPct = self:Clamp(
            (xp + math.max(0, rested or 0)) / maximum,
            0, 1
        )
    end

    local blueHeight = math.max(
        0, height * (restedPct - pct)
    )

    -- Current gold XP is hidden in Rested Only mode.
    xpFill:SetHeight(
        math.max(0.1, height * pct)
    )

    xpFill:SetShown(
        pct > 0 and mode ~= "rested"
    )

    -- Blue starts at the top of current earned XP.
    -- In Rested Only, gold is hidden, but the blue
    -- segment remains in the correct position.
    restedFill:ClearAllPoints()
    restedFill:SetPoint(
        "BOTTOMLEFT", xpInside, "BOTTOMLEFT",
        0, height * pct
    )
    restedFill:SetPoint(
        "BOTTOMRIGHT", xpInside, "BOTTOMRIGHT",
        0, height * pct
    )
    restedFill:SetHeight(
        math.max(0.1, blueHeight)
    )

    restedFill:SetShown(
        blueHeight > 0 and mode ~= "current"
    )
end

-- ============================================================
-- DISPLAY UPDATE
-- ============================================================

function FL:Refresh()
    if not self.db or not rows.kills
        or not self.session then
        return
    end

    local level, xp, maximum, remaining =
        self:XPData()

    local s = self.session

    local kills = self:KillEstimate(remaining)
    local quests = self:Estimate(
        remaining, s.quests, s.questXP
    )
    local rate = self:SelectedRate()

    local pct = 0

    if xp ~= nil and maximum and maximum > 0 then
        pct = self:Clamp(xp / maximum, 0, 1)
    end

    rows.kills.value:SetText(
        kills and ("~" .. self:Comma(kills)) or "--"
    )
    rows.kills.sub:SetText(
        self.db.killMode == "recent"
        and "RECENT" or "KILLS"
    )

    rows.quests.value:SetText(
        quests and ("~" .. self:Comma(quests)) or "--"
    )
    rows.quests.sub:SetText("QUESTS")

    rows.level.value:SetText(
        xp ~= nil and string.format("%.1f%%", pct * 100)
        or "--"
    )
    rows.level.sub:SetText(
        level and ("LV " .. level) or "LEVEL"
    )

    if rows.level.progress then
        rows.level.progress:SetWidth(
            math.max(0.1, 138 * pct)
        )
    end

    local eta

    if rate and rate > 0 and remaining then
        eta = remaining * 3600 / rate
    end

    rows.time.value:SetText(
        eta and self:Duration(eta) or "--"
    )

    rows.time.sub:SetText(
        self.db.timeMode == "active" and "ACTIVE"
        or self.db.timeMode == "recent" and "RECENT"
        or "TIME"
    )

    self:UpdateXPStrip(pct, xp, maximum)

    if self.journal and self.journal:IsShown() then
        self:UpdateJournal()
    end
end

-- ============================================================
-- END Tracker.lua v1.2.0
-- ============================================================
