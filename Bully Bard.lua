--[[
                                             __             __    
     	  ___ ________ ___ _  ___  ___ ____ / /  ___  ___  / /____
\\\\---- / _ `/ __/ _ `/  ' \/ _ \/ _ `(_-</ _ \/ _ \/ _ \/ __(_-< ----\
////---- \_, /_/  \_,_/_/_/_/ .__/\_,_/___/_//_/\___/\___/\__/___/ ----/
        /___/              /_/
    Bully Bard (full auto) v1.0

    Requirements:
    -------------
      • Peacemaking/Musicianship skills (to successfully calm hostile creatures)
      • At least one tambourine (graphic ID 3741) in your backpack (take a few to be sage)
      • A few hundred bandages (graphic ID 0x0E21) in your backpack
      • A safe roaming area where you can draw out and reset hostiles (newb dungeon is perfect)
      • “UO Sagas Assistant” API support for Mobiles, Spells, Targeting, Journal, Player, and Items

    Usage:
    ------
      This script automates your Bard’s Peacemaking routine in UO Sagas. It will:
        1. Continuously scan for the nearest hostile (Gray/Criminal) creature within SEARCH_RANGE.
        2. Automatically cast “Song of Peacemaking” on that target as soon as the cooldown allows.
        3. Immediately engage (single‐swing attack) the target to pull it under “calm” effect.
        4. Bandage your character whenever you take damage or become poisoned.
        5. Dynamically switch to any closer hostile if it enters range.
        6. Abandon a target and retarget if the target dies, moves out of view/range, or cannot be calmed.
        7. Continue looping indefinitely—even if no creatures are nearby—so you can walk around and re‐engage new mobs.

      The script relies on Journal messages to confirm success or failure:
        • “You play your hypnotic music, stopping the battle.”   → Peacemaking succeeded (green overhead), then a swing.
        • “That creature is already being calmed.”               → Still Calm! (yellow overhead), restart cooldown.
        • “You can’t see that.”                                   → Can’t see target! (red overhead), switch target.
        • “That is too far away.”                                → Too far away! (red overhead), switch target.
        • “You may not do that in this area”                      → Cannot calm here! (red overhead), restart cooldown.
        • “You cannot calm that”                                  → Cannot calm that creature! (red overhead), switch target.
        • “You play poorly, and there is no effect”               → Peacemaking failed! (red overhead), restart cooldown.
        • Any other message → Peacemaking result unknown (red overhead), restart cooldown.

    Configuration:
    --------------
      • SEARCH_RANGE:      Maximum tile radius to search for hostiles (default: 12).
      • Color constants:   Adjust COLOR_INFO, COLOR_ALERT, COLOR_SUCCESS, COLOR_HINT as desired.
      • MSG table:         Customize any overhead text strings at the top of the script.

    Notes:
    ------
      • Make sure you are in a location where hostiles can reset (e.g., near a spawn point).
      • Keep your tambourine and bandages in your backpack at all times.
      • The script runs in an infinite loop—press your macro’s stop key to end it.
      • It will not exit when no targets are found; simply walk into a new area to re‐engage.
      • This script does NOT handle any criminal‐act gump confirmations—close those manually if they appear.
]]  


--------------------------------------------------------------------------------
-- CONFIGURATION: Change these messages to your preference
--------------------------------------------------------------------------------
local MSG = {
    instrumentNotFound    = "Instrument not found!",
    noHostiles            = "No hostile monsters within %d tiles.",
    switchTo              = "Switching to: %s",
    targetDied            = "Target died: %s",
    peacemakingSucceeded  = "Peacemaking succeeded: %s",
    stillCalm             = "Still Calm!",
    cantSee               = "Can't see target!",
    tooFar                = "Too far away!",
    cannotCalmHere        = "Cannot calm here!",
    cannotCalmThat        = "Cannot calm that creature!",
    peacemakingFailed     = "Peacemaking failed!",
    peacemakingUnknown    = "Peacemaking result unknown",
    noBandages            = "No bandages!"
}

--------------------------------------------------------------------------------
-- CONFIGURATION: Other constants
--------------------------------------------------------------------------------
local SEARCH_RANGE = 12  -- Max tile radius for finding hostiles

-- Color constants for overhead text
local COLOR_INFO    = 93   -- Blue
local COLOR_ALERT   = 33   -- Red
local COLOR_SUCCESS = 73   -- Green
local COLOR_HINT    = 53   -- Yellow

--------------------------------------------------------------------------------
-- Cooldown helper (for bandaging)
--------------------------------------------------------------------------------
local Cooldown = {} do
    local data = {}
    setmetatable(Cooldown, {
        __call = function(t, key, value)
            if not value then
                -- READ remaining ms for “key”
                local cd = data[key]
                if not cd then 
                    return nil 
                end
                local elapsed = (os.clock() - cd.clock) * 1000
                local remaining = cd.delay - elapsed
                if remaining <= 0 then
                    data[key] = nil
                    return nil
                end
                return remaining
            else
                -- SET new cooldown in ms for “key”
                if value <= 0 then
                    data[key] = nil
                    return
                end
                data[key] = { clock = os.clock(), delay = value }
            end
        end,
        __index = function() return nil end,
        __newindex = function() error("Use Cooldown(key, value) instead") end
    })
end

--------------------------------------------------------------------------------
-- Fetch & sort all valid hostile mobiles (Gray or Criminal)
--------------------------------------------------------------------------------
local function GetSortedValidHostiles(range)
    local raw = Mobiles.FindByFilter({
        range       = { max = range },
        human       = false,
        notorieties = { 3, 4 }
    })
    local valid = {}
    for _, m in ipairs(raw) do
        -- Exclude self and any tamed/vendor pets (IsRenamable == true)
        if m.Serial ~= Player.Serial and not m.IsRenamable then
            table.insert(valid, m)
        end
    end
    table.sort(valid, function(a, b)
        return a.Distance < b.Distance
    end)
    return valid
end

--------------------------------------------------------------------------------
-- Calculate the Peacemaking cooldown based on Player.Dex
-- rawDelay = 10 - floor(Dex / 10), minimum = 6 seconds
--------------------------------------------------------------------------------
local function ComputePeacemakingCooldown()
    local dex = Player.Dex or 100
    local rawDelay = 10 - math.floor(dex / 10)
    if rawDelay < 6 then rawDelay = 6 end
    return rawDelay
end

--------------------------------------------------------------------------------
-- If hurt or poisoned and no bandage CD, use a bandage on self.
-- BandageCD = (8 + 0.85 * ((130 - Dex) / 20)) * 1000 ms
--------------------------------------------------------------------------------
local function TryBandageSelf()
    if Player.Hits < Player.HitsMax or Player.IsPoisoned then
        if not Cooldown("BandageSelf") then
            local b = Items.FindByType(0x0E21)
            if b then
                if Player.UseObject(b.Serial) then
                    if Targeting.WaitForTarget(500) then
                        Targeting.TargetSelf()
                        local dex = Player.Dex or 100
                        local delay = (8.0 + 0.85 * ((130 - dex) / 20)) * 1000
                        Cooldown("BandageSelf", delay)
                    end
                end
            else
                Messages.Overhead(MSG.noBandages, COLOR_ALERT, Player.Serial)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Attempt a single‐swing attack on the given serial.
-- If Player.Attack exists, use it. Otherwise, do a bare‐hand punch
--------------------------------------------------------------------------------
local function TryEngageTarget(serial)
    if Player.Attack then
        Player.Attack(serial)
    else
        if Targeting.WaitForTarget(500) then
            Targeting.Target(serial)
        end
    end
end

--------------------------------------------------------------------------------
-- MAIN LOOP
--------------------------------------------------------------------------------

-- 1) Ensure a tambourine (graphic ID 3741) is in the backpack
local tambourine = Items.FindByType(3741)
if not tambourine then
    Messages.Overhead(MSG.instrumentNotFound, COLOR_ALERT, Player.Serial)
    return
end

-- Variables to track the current target and next allowable Peacemaking time
local currentTarget = nil
local nextPeaceTime  = 0
local peaceCooldown  = ComputePeacemakingCooldown()

-- Outer infinite loop: bandage + dynamic targeting + pacify
while true do
    --------------------------------------------------------------------------------
    -- 2) Bandage priority each iteration
    --------------------------------------------------------------------------------
    TryBandageSelf()

    --------------------------------------------------------------------------------
    -- 3) Gather sorted hostiles and pick nearest
    --------------------------------------------------------------------------------
    local hostiles = GetSortedValidHostiles(SEARCH_RANGE)
    if #hostiles == 0 then
        -- No hostiles found: clear currentTarget, but DO NOT exit.
        currentTarget = nil
        Pause(500)
        goto continue_outer
    end

    local nearest = hostiles[1]

    --------------------------------------------------------------------------------
    -- 3a) If there is no current target or a closer one appears, switch
    --------------------------------------------------------------------------------
    if not currentTarget or nearest.Serial ~= currentTarget.Serial then
        currentTarget = nearest
        Messages.Overhead(
            string.format(MSG.switchTo, currentTarget.Name or "<unknown>"),
            COLOR_INFO,
            currentTarget.Serial
        )
        -- Immediately attempt to engage this new target:
        TryEngageTarget(currentTarget.Serial)
    end

    --------------------------------------------------------------------------------
    -- 4) Confirm the current target still exists and is alive
    --------------------------------------------------------------------------------
    local targetData = Mobiles.FindBySerial(currentTarget.Serial)
    if not targetData or targetData.IsDead then
        Messages.Overhead(
            string.format(MSG.targetDied, currentTarget.Name or "<unknown>"),
            COLOR_HINT,
            Player.Serial
        )
        currentTarget = nil
        Pause(200)
        goto continue_outer
    end

    --------------------------------------------------------------------------------
    -- 5) Attempt Peacemaking when cooldown has expired
    --------------------------------------------------------------------------------
    local now = os.clock()
    if now >= nextPeaceTime then
        -- 5a) Clear journal before casting
        Journal.Clear()

        -- 5b) Cast Peacemaking
        Player.UseObject(tambourine.Serial)
        Spells.Cast("SongOfPeacemaking")
        Pause(250)

        -- 5c) Re‐check if target died mid‐cast
        targetData = Mobiles.FindBySerial(currentTarget.Serial)
        if not targetData or targetData.IsDead then
            Messages.Overhead(
                string.format(MSG.targetDied, currentTarget.Name or "<unknown>"),
                COLOR_ALERT,
                Player.Serial
            )
            nextPeaceTime = now + peaceCooldown
            currentTarget = nil
            Pause(200)
            goto continue_outer
        end

        -- 5d) Proceed to target creature for Peacemaking effect
        if Targeting.WaitForTarget(1000) then
            Targeting.Target(currentTarget.Serial)
        else
            Messages.Overhead(
                string.format(MSG.peacemakingUnknown),
                COLOR_ALERT,
                Player.Serial
            )
            nextPeaceTime = now + peaceCooldown
            Pause(200)
            goto continue_outer
        end

        -- 5e) Wait for journal to populate
        Pause(500)

        -- 5f) Inspect journal for EXACT messages in priority order:
        if Journal.Contains("You play your hypnotic music, stopping the battle.") then
            -- Success
            Messages.Overhead(
                string.format(MSG.peacemakingSucceeded, currentTarget.Name or "<unknown>"),
                COLOR_SUCCESS,
                currentTarget.Serial
            )
            -- Engage again in case the first punch didn't register
            TryEngageTarget(currentTarget.Serial)
            nextPeaceTime = now + peaceCooldown

        elseif Journal.Contains("That creature is already being calmed.") then
            -- Already calm
            Messages.Overhead(MSG.stillCalm, COLOR_HINT, currentTarget.Serial)
            nextPeaceTime = now + peaceCooldown

        elseif Journal.Contains("You can’t see that") or Journal.Contains("You can't see that") then
            -- Cannot see: abandon target
            Messages.Overhead(MSG.cantSee, COLOR_ALERT, currentTarget.Serial)
            currentTarget = nil
            nextPeaceTime = now + peaceCooldown
            Pause(200)
            goto continue_outer

        elseif Journal.Contains("That is too far away") then
            -- Too far: abandon target
            Messages.Overhead(MSG.tooFar, COLOR_ALERT, currentTarget.Serial)
            currentTarget = nil
            nextPeaceTime = now + peaceCooldown
            Pause(200)
            goto continue_outer

        elseif Journal.Contains("You may not do that in this area") then
            Messages.Overhead(MSG.cannotCalmHere, COLOR_ALERT, currentTarget.Serial)
            nextPeaceTime = now + peaceCooldown

        elseif Journal.Contains("You cannot calm that") then
            -- Explicit “cannot calm that” → abandon target
            Messages.Overhead(MSG.cannotCalmThat, COLOR_ALERT, currentTarget.Serial)
            currentTarget = nil
            nextPeaceTime = now + peaceCooldown
            Pause(200)
            goto continue_outer

        elseif Journal.Contains("You play poorly, and there is no effect") then
            -- Failed Peacemaking
            Messages.Overhead(MSG.peacemakingFailed, COLOR_ALERT, currentTarget.Serial)
            nextPeaceTime = now + peaceCooldown

        else
            -- Any other/unrecognized line
            Messages.Overhead(MSG.peacemakingUnknown, COLOR_ALERT, currentTarget.Serial)
            nextPeaceTime = now + peaceCooldown
        end
    end

    --------------------------------------------------------------------------------
    -- 6) Small pause before next iteration (allows bandaging & retarget checks)
    --------------------------------------------------------------------------------
    Pause(200)

    ::continue_outer::
end
