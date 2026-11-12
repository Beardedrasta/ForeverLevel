-- ============================================================
-- FOREVER LEVEL v1.3.0
-- Config.lua - COMPLETE REPLACEMENT
-- ============================================================

local _, FL = ...

local window
local controls = {}

local function Label(y, text)
    local t = FL:Text(window, "GameFontNormal")
    t:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, y
    )
    t:SetText(text)
    t:SetTextColor(0.88, 0.73, 0.46)
    return t
end

local function Button(text, w, h, click)
    return FL:Button(window, text, w, h, click)
end

local function SetTimeMode(mode)
    FL.db.timeMode = mode
    FL:Refresh()
    FL:UpdateConfig()
end

local function SetBarMode(mode)
    FL.db.xpBarMode = mode
    FL:Refresh()
    FL:UpdateConfig()
end

local function SetBorder(name)
    FL.db.borderPreset = name
    FL:RefreshBorderColors()
    FL:UpdateConfig()
end

-- ============================================================
-- BUILD CONFIG
-- ============================================================

function FL:BuildConfig()
    window = CreateFrame(
        "Frame", "ForeverLevelOptions",
        UIParent, "BackdropTemplate"
    )

    self.config = window

    window:SetSize(370, 805)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")

    self:Style(window, 0.99, 18)

    window:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local heading = self:Text(
        window, "GameFontNormalLarge"
    )
    heading:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -16
    )
    heading:SetText("FOREVER LEVEL")
    heading:SetTextColor(unpack(self.GOLD))

    local subtitle = self:Text(
        window, "GameFontHighlightSmall"
    )
    subtitle:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -40
    )
    subtitle:SetText("CONFIGURATION | v1.3.0")

    local close = Button(
        "X", 25, 24, function() window:Hide() end
    )
    close:SetPoint(
        "TOPRIGHT", window, "TOPRIGHT", -12, -12
    )

    -- Layout.
    Label(-68, "LAYOUT")

    local dock = Button(
        "Docked", 155, 25,
        function()
            FL:SavePositions()
            FL.db.mode = "dock"
            FL:ApplyLayout()
        end
    )
    dock:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -89
    )

    local detach = Button(
        "Detached", 155, 25,
        function()
            FL:SavePositions()
            FL.db.mode = "detached"
            FL:ApplyLayout()
        end
    )
    detach:SetPoint(
        "LEFT", dock, "RIGHT", 9, 0
    )

    -- Appearance.
    Label(-128, "APPEARANCE")

    controls.scale = Label(-153, "")

    local scaleMinus = Button(
        "-", 35, 24,
        function()
            FL:SavePositions()
            FL.db.scale = FL:Clamp(
                FL.db.scale - 0.05, 0.70, 1.50
            )
            FL:ApplyLayout()
        end
    )
    scaleMinus:SetPoint(
        "TOPRIGHT", window, "TOPRIGHT", -93, -147
    )

    local scalePlus = Button(
        "+", 35, 24,
        function()
            FL:SavePositions()
            FL.db.scale = FL:Clamp(
                FL.db.scale + 0.05, 0.70, 1.50
            )
            FL:ApplyLayout()
        end
    )
    scalePlus:SetPoint(
        "LEFT", scaleMinus, "RIGHT", 5, 0
    )

    controls.opacity = Label(-192, "")

    local opacityMinus = Button(
        "-", 35, 24,
        function()
            FL.db.opacity = FL:Clamp(
                FL.db.opacity - 0.05, 0.50, 1
            )
            FL:ApplyLayout()
        end
    )
    opacityMinus:SetPoint(
        "TOPRIGHT", window, "TOPRIGHT", -93, -186
    )

    local opacityPlus = Button(
        "+", 35, 24,
        function()
            FL.db.opacity = FL:Clamp(
                FL.db.opacity + 0.05, 0.50, 1
            )
            FL:ApplyLayout()
        end
    )
    opacityPlus:SetPoint(
        "LEFT", opacityMinus, "RIGHT", 5, 0
    )

    -- Visibility.
    Label(-231, "PANEL VISIBILITY")
    controls.visibility = {}

    for i, kind in ipairs(self.order) do
        local k = kind
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)

        local b = Button(
            "", 155, 25,
            function()
                FL.db.hidden[k] =
                    not FL.db.hidden[k]

                FL:ApplyLayout()
            end
        )

        b:SetPoint(
            "TOPLEFT", window, "TOPLEFT",
            19 + col * 164,
            -254 - row * 32
        )

        controls.visibility[k] = b
    end

    -- Projection modes.
    Label(-335, "TIME TO LEVEL ESTIMATION")
    controls.time = {}

    local timeModes = {
        { "session", "Full Session" },
        { "recent",  "Recent 5 Min" },
        { "active",  "Active Leveling" },
    }

    for i, entry in ipairs(timeModes) do
        local mode = entry[1]

        local b = Button(
            entry[2], 100, 26,
            function()
                SetTimeMode(mode)
            end
        )

        b:SetPoint(
            "TOPLEFT", window, "TOPLEFT",
            19 + (i - 1) * 110, -358
        )

        controls.time[mode] = b
    end

    -- Active window.
    Label(-405, "ACTIVE LEVELING WINDOW")
    controls.activity = {}

    for i, seconds in ipairs({ 60, 90, 120 }) do
        local number = seconds

        local b = Button(
            number .. " sec", 100, 25,
            function()
                FL:SetActivityWindow(number)
                FL:UpdateConfig()
            end
        )

        b:SetPoint(
            "TOPLEFT", window, "TOPLEFT",
            19 + (i - 1) * 110, -428
        )

        controls.activity[number] = b
    end

    local activityNote = self:Text(
        window, "GameFontHighlightSmall"
    )
    activityNote:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -463
    )
    activityNote:SetWidth(325)
    activityNote:SetJustifyH("LEFT")
    activityNote:SetText(
        "Time is estimated after observed XP gains. "
        .. "Longer windows also count more downtime."
    )
    activityNote:SetTextColor(0.68, 0.64, 0.55)

    -- Kill estimates.
    Label(-501, "KILL ESTIMATION")

    controls.killSession = Button(
        "Session Kills", 155, 25,
        function()
            FL.db.killMode = "session"
            FL:Refresh()
            FL:UpdateConfig()
        end
    )
    controls.killSession:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -524
    )

    controls.killRecent = Button(
        "Last 20 Kills", 155, 25,
        function()
            FL.db.killMode = "recent"
            FL:Refresh()
            FL:UpdateConfig()
        end
    )
    controls.killRecent:SetPoint(
        "LEFT", controls.killSession, "RIGHT", 9, 0
    )

    -- XP bar: TWO choices only.
    Label(-568, "VERTICAL XP BAR")

    controls.bar = {}

    local barModes = {
        { "current", "Current XP" },
        { "both",    "Current + Rested" },
    }

    for i, entry in ipairs(barModes) do
        local mode = entry[1]

        local b = Button(
            entry[2], 155, 25,
            function()
                SetBarMode(mode)
            end
        )

        b:SetPoint(
            "TOPLEFT", window, "TOPLEFT",
            19 + (i - 1) * 164, -591
        )

        controls.bar[mode] = b
    end

    -- Border style.
    Label(-637, "BLIZZARD BORDER STYLE")
    controls.border = {}

    local presets = {
        { "antique", "Antique" },
        { "royal",   "Royal" },
        { "bright",  "Bright" },
    }

    for i, entry in ipairs(presets) do
        local name = entry[1]

        local b = Button(
            entry[2], 100, 25,
            function()
                SetBorder(name)
            end
        )

        b:SetPoint(
            "TOPLEFT", window, "TOPLEFT",
            19 + (i - 1) * 110, -660
        )

        controls.border[name] = b
    end

    -- Actions.
    controls.lock = Button(
        "", 155, 25,
        function()
            FL.db.locked = not FL.db.locked
            FL:UpdateConfig()
        end
    )
    controls.lock:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -705
    )

    local reset = Button(
        "Reset Session", 155, 25,
        function()
            FL:ResetSession()
            FL:Refresh()
            FL:Say("Session reset; lifetime retained.")
        end
    )
    reset:SetPoint(
        "LEFT", controls.lock, "RIGHT", 9, 0
    )

    local journalButton = Button(
        "Open Leveling Journal", 319, 28,
        function()
            window:Hide()
            FL:ToggleJournal(true)
        end
    )
    journalButton:SetPoint(
        "TOPLEFT", window, "TOPLEFT", 19, -747
    )

    window:Hide()
    self:UpdateConfig()
end

-- ============================================================
-- UPDATE CONFIG
-- ============================================================

function FL:UpdateConfig()
    if not window or not self.db then return end

    local db = self.db

    controls.scale:SetText(string.format(
        "Tracker scale: %d%%",
        math.floor(db.scale * 100 + 0.5)
    ))

    controls.opacity:SetText(string.format(
        "Background opacity: %d%%",
        math.floor(db.opacity * 100 + 0.5)
    ))

    for _, kind in ipairs(self.order) do
        controls.visibility[kind]:SetText(
            (db.hidden[kind] and "Show " or "Hide ")
            .. self.info[kind].label
        )
    end

    local timeLabels = {
        session = "Full Session",
        recent = "Recent 5 Min",
        active = "Active Leveling",
    }

    for mode, b in pairs(controls.time) do
        local text = timeLabels[mode]

        b:SetText(
            db.timeMode == mode
            and ("[" .. text .. "]") or text
        )
    end

    for seconds, b in pairs(controls.activity) do
        local text = seconds .. " sec"

        b:SetText(
            db.activeWindow == seconds
            and ("[" .. text .. "]") or text
        )
    end

    controls.killSession:SetText(
        db.killMode == "session"
        and "[ Session Kills ]" or "Session Kills"
    )

    controls.killRecent:SetText(
        db.killMode == "recent"
        and "[ Last 20 Kills ]" or "Last 20 Kills"
    )

    local barNames = {
        current = "Current XP",
        both = "Current + Rested",
    }

    for mode, b in pairs(controls.bar) do
        local text = barNames[mode]

        b:SetText(
            db.xpBarMode == mode
            and ("[" .. text .. "]") or text
        )
    end

    for name, b in pairs(controls.border) do
        local text = name:sub(1, 1):upper()
            .. name:sub(2)

        b:SetText(
            db.borderPreset == name
            and ("[" .. text .. "]") or text
        )
    end

    controls.lock:SetText(
        db.locked and "Unlock Panels"
        or "Lock Panels"
    )
end

function FL:ToggleConfig(force)
    if not window then return end

    if force == true then
        self:UpdateConfig()
        window:Show()
    elseif window:IsShown() then
        window:Hide()
    else
        self:UpdateConfig()
        window:Show()
    end
end

-- ============================================================
-- END Config.lua v1.3.0
-- ============================================================
