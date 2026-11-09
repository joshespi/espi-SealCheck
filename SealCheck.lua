-- SealCheck: in-combat "no seal" warning for WoW Forever.
-- Buffs are secret in combat, so seal state comes from:
--   out of combat: real aura scan (also learns each seal's duration + icon)
--   in combat:     your own seal casts + learned duration
-- Judgement doesn't consume the seal on Forever, so it isn't tracked.

local SEAL_PATTERN = "^Seal of "
local DEFAULT_DURATION = 30
local TICK = 0.2
local TEST_SECS = 3
local FALLBACK_ICON = "Interface\\Icons\\Ability_ThunderBolt"

local defaults = {
    enabled = true,
    sound = true,
    size = 64,
    point = { "CENTER", "UIParent", "CENTER", 0, 180 },
    warnTime = 5,        -- seconds left to show the "expiring" cue, 0 = off
    repeatEvery = 0,     -- re-ping sound every N sec while unsealed, 0 = off
    grace = 1,           -- seconds after combat start before alerting
    hideMounted = true,
    hideVehicle = true,
    durations = {},      -- learned seal durations, by seal name
}

local VISUALS = {
    alert  = { color = { 1, 0.25, 0.25 }, text = "NO SEAL", pulse = true },
    warn   = { color = { 1, 0.85, 0.2 },  text = "SEAL EXPIRING" },
    unlock = { color = { 0.3, 1, 0.4 },   text = "DRAG ME" },
}

local issecret = issecretvalue or function() return false end

local db
local category              -- Settings category, if registered
local inCombat = false
local combatStart = 0
local blind = false         -- own cast came back secret; can't track this fight
local sealExpires = 0       -- GetTime() the current seal ends, 0 = none
local visual                -- current visual state: "alert" | "warn" | "unlock" | nil
local timerText = ""
local lastPing = 0
local unlocked = false
local testUntil = 0

local function Print(msg)
    print("|cffff5555Espi SealCheck|r: " .. msg)
end

local function IsSeal(name)
    if issecret(name) or type(name) ~= "string" then return false end
    return name:find(SEAL_PATTERN) ~= nil
end

-- warning frame

local warn = CreateFrame("Frame", "SealCheckWarning", UIParent)
warn:SetFrameStrata("HIGH")
warn:SetClampedToScreen(true)
warn:SetMovable(true)
warn:EnableMouse(false)
warn:RegisterForDrag("LeftButton")
warn:Hide()

local icon = warn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetDesaturated(true)

local border = warn:CreateTexture(nil, "BACKGROUND", nil, -1)
border:SetPoint("TOPLEFT", -2, 2)
border:SetPoint("BOTTOMRIGHT", 2, -2)
border:SetColorTexture(1, 1, 1, 1)

local label = warn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
label:SetPoint("TOP", warn, "BOTTOM", 0, -4)

local timer = warn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
timer:SetPoint("CENTER", warn, "CENTER", 0, 0)
timer:SetTextColor(1, 1, 1)

local pulse = warn:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(1)
fade:SetToAlpha(0.3)
fade:SetDuration(0.5)

warn:SetScript("OnDragStart", warn.StartMoving)
warn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.point = { p, "UIParent", rp, x, y }
end)

local fontPath = GameFontNormalLarge:GetFont()

local function ApplyLayout()
    local p = db.point
    warn:ClearAllPoints()
    warn:SetPoint(p[1], UIParent, p[3], p[4], p[5])
    warn:SetSize(db.size, db.size)
    label:SetFont(fontPath, math.max(10, math.floor(db.size * 0.28)), "OUTLINE")
    timer:SetFont(fontPath, math.max(10, math.floor(db.size * 0.4)), "OUTLINE")
end

local function SetIcon(tex)
    if tex and not issecret(tex) then
        db.lastIcon = tex
        icon:SetTexture(tex)
    end
end

-- state

-- Event frame doubles as the ticker: its OnUpdate only runs while it is shown,
-- and Update() shows it only while something can change on its own.
local ev = CreateFrame("Frame")

local function CombatState(now)
    if not db.enabled or not inCombat or blind then return nil end

    local state
    if now >= sealExpires then
        if now < combatStart + db.grace then return nil end
        state = "alert"
    elseif db.warnTime > 0 and sealExpires - now <= db.warnTime then
        state = "warn"
    else
        return nil
    end

    if UnitIsDeadOrGhost("player") then return nil end
    if db.hideMounted and IsMounted() then return nil end
    if db.hideVehicle and UnitInVehicle and UnitInVehicle("player") then return nil end
    return state
end

local function GetState(now)
    if now < testUntil then return "alert" end
    return CombatState(now) or (unlocked and "unlock" or nil)
end

local function ApplyVisual(state)
    if state == visual then return end
    visual = state
    local v = state and VISUALS[state]
    if v and v.pulse then
        pulse:Play()
    else
        pulse:Stop()
        warn:SetAlpha(1)
    end
    if not v then
        warn:Hide()
        return
    end
    local r, g, b = unpack(v.color)
    icon:SetVertexColor(r, g, b)
    border:SetVertexColor(r, g, b)
    label:SetTextColor(r, g, b)
    label:SetText(v.text)
    warn:Show()
end

local function Update()
    local now = GetTime()
    local state = GetState(now)

    if state == "alert" and db.sound then
        local fresh = visual ~= "alert"
        local again = db.repeatEvery > 0 and now - lastPing >= db.repeatEvery
        if fresh or again then
            PlaySound(SOUNDKIT.RAID_WARNING, "Master")
            lastPing = now
        end
    end

    -- countdown on the icon while the seal is about to drop
    local t = state == "warn" and string.format("%d", math.max(0, math.ceil(sealExpires - now))) or ""
    if t ~= timerText then
        timer:SetText(t)
        timerText = t
    end

    ApplyVisual(state)

    if inCombat or now < testUntil then ev:Show() else ev:Hide() end
end

-- settings: every change from the options panel or slash commands goes through here

local refreshers = {}

local function RefreshOptions()
    for _, r in ipairs(refreshers) do r() end
end

local NUMBERS = {
    { key = "size",        cmd = "size",   lo = 16, hi = 256, step = 4,   fmt = "%d px",  onChange = ApplyLayout,
      panel = "Icon size",                    chat = "size",               unit = "px" },
    { key = "warnTime",    cmd = "warn",   lo = 0,  hi = 15,  step = 1,   fmt = "%d s",
      panel = "Expiring warning (0 = off)",   chat = "expiring warning",   unit = "s (0 = off)" },
    { key = "repeatEvery", cmd = "repeat", lo = 0,  hi = 30,  step = 1,   fmt = "%d s",
      panel = "Repeat sound every (0 = off)", chat = "repeat sound",       unit = "s (0 = off)" },
    { key = "grace",       cmd = "grace",  lo = 0,  hi = 5,   step = 0.5, fmt = "%.1f s",
      panel = "Combat-start grace",           chat = "combat-start grace", unit = "s" },
}

local TOGGLES = {
    { key = "enabled",     panel = "Enable Espi SealCheck" },
    { key = "sound",       panel = "Play warning sound",      cmd = "sound",   chat = "sound" },
    { key = "hideMounted", panel = "Hide while mounted",      cmd = "mounted", chat = "hide while mounted" },
    { key = "hideVehicle", panel = "Hide while in a vehicle", cmd = "vehicle", chat = "hide in vehicle" },
}

local NUMBER_CMDS, TOGGLE_CMDS = {}, {}
for _, n in ipairs(NUMBERS) do NUMBER_CMDS[n.cmd] = n end
for _, t in ipairs(TOGGLES) do if t.cmd then TOGGLE_CMDS[t.cmd] = t end end

local function SetNumber(n, v)
    v = math.floor(v / n.step + 0.5) * n.step
    db[n.key] = math.max(n.lo, math.min(n.hi, v))
    if n.onChange then n.onChange() end
    Update()
end

local function SetToggle(key, v)
    db[key] = v
    Update()
end

local function SetUnlocked(v)
    unlocked = v
    warn:EnableMouse(v)
    RefreshOptions()
    Update()
end

local function StartTest()
    testUntil = GetTime() + TEST_SECS
    Update()
end

local function ResetLayout()
    db.point = { unpack(defaults.point) }
    db.size = defaults.size
    ApplyLayout()
    RefreshOptions()
end

-- Only trusted out of combat. Bails without touching state if anything is secret.
local function ScanAuras()
    if inCombat or InCombatLockdown() then return end
    local expires = 0
    local i = 1
    while true do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if aura == nil then break end
        if issecret(aura) or issecret(aura.name) then return end
        if IsSeal(aura.name) then
            local dur, exp = aura.duration, aura.expirationTime
            if issecret(dur) or issecret(exp) then return end
            if dur and dur > 0 then
                db.durations[aura.name] = dur
                expires = exp
            else
                expires = math.huge
            end
            SetIcon(aura.icon)
            break
        end
        i = i + 1
    end
    sealExpires = expires
end

-- Returns true if the cast changed tracked state.
local function OnCast(spellID)
    if issecret(spellID) then
        if not inCombat then return false end
        blind = true
        return true
    end
    local name = C_Spell.GetSpellName(spellID)
    if not IsSeal(name) then return false end
    sealExpires = GetTime() + (db.durations[name] or DEFAULT_DURATION)
    SetIcon(C_Spell.GetSpellTexture(spellID))
    return true
end

-- options panel

local function BuildOptions()
    local panel = CreateFrame("Frame")
    panel.name = "Espi SealCheck"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Espi SealCheck")

    local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("Warns you in combat when you have no Seal active.")

    local y = -80

    local function Check(t)
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 16, y)
        local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        fs:SetText(t.panel)
        cb:SetHitRectInsets(0, -(fs:GetStringWidth() + 4), 0, 0)  -- label clickable too
        cb:SetScript("OnClick", function(self)
            SetToggle(t.key, self:GetChecked() and true or false)
        end)
        refreshers[#refreshers + 1] = function() cb:SetChecked(db[t.key]) end
        y = y - 28
    end

    local sliderCount = 0
    local function Slider(n)
        sliderCount = sliderCount + 1
        local name = "SealCheckSlider" .. sliderCount
        local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", 24, y - 16)
        s:SetWidth(220)
        s:SetMinMaxValues(n.lo, n.hi)
        s:SetValueStep(n.step)
        if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
        local low = s.Low or _G[name .. "Low"]
        local high = s.High or _G[name .. "High"]
        local txt = s.Text or _G[name .. "Text"]
        if low then low:SetText(n.lo) end
        if high then high:SetText(n.hi) end
        local updating = false
        local function show(v)
            if txt then txt:SetText(n.panel .. ": " .. string.format(n.fmt, v)) end
        end
        s:SetScript("OnValueChanged", function(_, v)
            show(v)
            if not updating then SetNumber(n, v) end
        end)
        refreshers[#refreshers + 1] = function()
            updating = true
            s:SetValue(db[n.key])
            show(db[n.key])
            updating = false
        end
        y = y - 48
    end

    local function Button(text, onClick, x)
        local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
        b:SetSize(120, 24)
        b:SetPoint("TOPLEFT", x, y)
        b:SetText(text)
        b:SetScript("OnClick", onClick)
        return b
    end

    for _, t in ipairs(TOGGLES) do Check(t) end
    y = y - 8
    for _, n in ipairs(NUMBERS) do Slider(n) end
    y = y - 8

    local lockBtn = Button("Unlock", function() SetUnlocked(not unlocked) end, 16)
    refreshers[#refreshers + 1] = function() lockBtn:SetText(unlocked and "Lock" or "Unlock") end
    Button("Test", StartTest, 144)
    Button("Reset position", ResetLayout, 272)

    panel:SetScript("OnShow", RefreshOptions)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
        category = panel
    end
end

local function OpenOptions()
    if not category then
        Print("options panel unavailable")
    elseif Settings and Settings.OpenToCategory and category.GetID then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(category)
        InterfaceOptionsFrame_OpenToCategory(category)
    end
end

-- events

ev:RegisterEvent("PLAYER_LOGIN")

local acc = 0
local function OnTick(_, dt)
    acc = acc + dt
    if acc < TICK then return end
    acc = 0
    Update()
end

ev:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        if class ~= "PALADIN" then return end

        SealCheckDB = SealCheckDB or {}
        db = SealCheckDB
        for k, v in pairs(defaults) do
            if db[k] == nil then
                db[k] = type(v) == "table" and { unpack(v) } or v
            end
        end
        icon:SetTexture(db.lastIcon or FALLBACK_ICON)
        ApplyLayout()

        local ok, err = pcall(BuildOptions)
        if not ok then Print("options panel failed: " .. tostring(err)) end

        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_DEAD")
        self:RegisterUnitEvent("UNIT_AURA", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:SetScript("OnUpdate", OnTick)

    elseif event == "PLAYER_ENTERING_WORLD" then
        inCombat = InCombatLockdown()
        if inCombat then
            -- reloaded mid-fight: auras are secret and we missed the casts
            combatStart = GetTime()
            blind = true
        end
        ScanAuras()

    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        combatStart = GetTime()
        blind = false

    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        blind = false
        ScanAuras()

    elseif event == "PLAYER_DEAD" then
        sealExpires = 0

    elseif event == "UNIT_AURA" then
        if inCombat then return end   -- auras are secret; the tick covers combat
        ScanAuras()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        if not OnCast(spellID) then return end
    end

    Update()
end)

-- slash

local function OnOff(v) return v and "on" or "off" end

local HELP = {
    "/seal config - open options panel",
    "/seal unlock | lock - move the icon",
    "/seal test - preview the alert",
    "/seal toggle | sound | mounted | vehicle - toggles",
    "/seal size <16-256> | warn <sec> | repeat <sec> | grace <sec>",
    "/seal reset | status",
}

SLASH_SEALCHECK1 = "/sealcheck"
SLASH_SEALCHECK2 = "/seal"
SlashCmdList.SEALCHECK = function(msg)
    if not db then
        Print("paladin only")
        return
    end
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local n, t = NUMBER_CMDS[cmd], TOGGLE_CMDS[cmd]

    if n then
        local num = tonumber(arg)
        if num then
            SetNumber(n, num)
            RefreshOptions()
            Print(string.format("%s set to %s%s", n.chat, tostring(db[n.key]), n.unit))
        else
            Print(string.format("%s is %s%s. Usage: /seal %s <%s-%s>",
                n.chat, tostring(db[n.key]), n.unit, cmd, n.lo, n.hi))
        end
    elseif t then
        SetToggle(t.key, not db[t.key])
        RefreshOptions()
        Print(t.chat .. " " .. OnOff(db[t.key]))
    elseif cmd == "toggle" then
        SetToggle("enabled", not db.enabled)
        RefreshOptions()
        Print(db.enabled and "enabled" or "disabled")
    elseif cmd == "config" or cmd == "options" then
        OpenOptions()
    elseif cmd == "unlock" then
        SetUnlocked(true)
        Print("unlocked, drag to move. /seal lock when done")
    elseif cmd == "lock" then
        SetUnlocked(false)
        Print("locked")
    elseif cmd == "test" then
        StartTest()
        Print(string.format("previewing alert for %ds", TEST_SECS))
    elseif cmd == "reset" then
        ResetLayout()
        Print("position and size reset")
    elseif cmd == "status" then
        local left = sealExpires - GetTime()
        local s = sealExpires == 0 and "none"
            or sealExpires == math.huge and "no expiry"
            or left > 0 and string.format("%.0fs left (est.)", left)
            or "expired"
        Print("seal: " .. s .. (blind and ", blind this fight" or ""))
        for name, dur in pairs(db.durations) do
            Print(string.format("  %s = %ds", name, dur))
        end
    else
        for _, line in ipairs(HELP) do Print(line) end
    end
end
