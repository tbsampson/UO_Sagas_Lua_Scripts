--[[
                                             __             __    
     	  ___ ________ ___ _  ___  ___ ____ / /  ___  ___  / /____
\\\\---- / _ `/ __/ _ `/  ' \/ _ \/ _ `(_-</ _ \/ _ \/ _ \/ __(_-< ----\
////---- \_, /_/  \_,_/_/_/_/ .__/\_,_/___/_//_/\___/\___/\__/___/ ----/
        /___/ /_/
Magery Trainer v 1.15

Requirements:
------
  • Healing/Anatomy (Train at NPC to ~30 is fine)
  • A few hundred bandages, plenty of reagents (see list below), and a safe place to macro

Usage:
------
This script automates your magery training in UO Sagas.
It will automatically cast offensive spells on your character, then heal using bandages.
If no bandages remain, it will switch to casting “Heal” (and “GreaterHeal” only if Mandrake Root is present),
until reagents run out.

The script selects offensive spells dynamically based on your Magery skill level,
from Magic Arrow to Flamestrike. It also uses Meditation to recover mana when it falls
below 10%, and will proactively meditate on cooldown whenever mana is above 50% to
maximize Meditation casts. When using magery to heal (Heal/GreaterHeal), it will
immediately attempt to cast Meditation if the skill is ready.

Added Option:
-------------
  • AUTO_HEAL (true/false): If false, skip all healing routines (bandage/magery). 
    The script will not heal but also will not cast offensive spells if health ≤ HEALTH_THRESHOLD.

Make sure to have plenty of bandages and the required spell reagents
in your backpack. The script runs in an infinite loop—press your macro’s stop key to end.

Reagents required:
---------------------------------
  • Magic Arrow:    Sulfurous Ash
  • Fireball:       Black Pearl
  • Lightning:      Mandrake Root, Sulfurous Ash
  • Energy Bolt:    Black Pearl, Nightshade
  • Flamestrike:    Spider's Silk, Sulfurous Ash
  • Heal:           Garlic, Ginseng, Spider's Silk
  • GreaterHeal:    Garlic, Ginseng, Spider's Silk, Mandrake Root

Note: This script assumes you have enough reagents to sustain casting and that you are in a safe location for training.
]]--

-- === Configuration Constants ===
local AUTO_HEAL               = true       -- Set to false if another player will handle healing
local GRAPHIC_BANDAGE         = 0x0E21     -- Item ID for bandages
local DELAY_HEAL              = 14000      -- Delay after bandaging or Heal (ms)
local DELAY_CAST              = 1500       -- Delay after casting offensive spells (ms)
local DELAY_LOOP              = 1000       -- Delay between loop iterations when idle (ms)
local HEALTH_THRESHOLD        = 65         -- Heal if health is below or equal to this
local MANA_LOW_THRESHOLD      = 0.10       -- 10% of MaxMana: threshold to force meditate to full
local MANA_MEDIATE_THRESHOLD  = 0.50       -- 50% of MaxMana: threshold to proactively meditate

-- === Color Constants for Overhead Messages ===
local COLOR_INFO    = 93   -- Blue
local COLOR_ALERT   = 33   -- Red
local COLOR_HINT    = 53   -- Yellow

-- === Spell Definitions (Offensive) ===
local SPELLBOOK = {
    { name = "MagicArrow",   skillMin = 0,   skillMax = 30,  manaCost = 4 },
    { name = "Fireball",     skillMin = 30,  skillMax = 50,  manaCost = 9 },
    { name = "Lightning",    skillMin = 50,  skillMax = 70,  manaCost = 11 },
    { name = "EnergyBolt",   skillMin = 70,  skillMax = 90,  manaCost = 20 },
    { name = "Flamestrike",  skillMin = 90,  skillMax = 100, manaCost = 40 }
}

-- === Reagent Graphic IDs for Healing Spells ===
local REAGENT_GARLIC      = 0x0F84  -- Garlic
local REAGENT_GINSENG     = 0x0F85  -- Ginseng
local REAGENT_SPIDERSILK  = 0x0E1C  -- Spider's Silk
local REAGENT_MANDRAKE    = 0x0F8C  -- Mandrake Root

-- === Helper Functions ===

-- Find the first bandage in the player's backpack (strictly inside backpack)
local function FindBandage()
    local item = Items.FindByType(GRAPHIC_BANDAGE)
    if item and item.RootContainer == Player.Serial then
        return item
    end
    return nil
end

-- Count how many of a given reagent graphic are in backpack
local function CountReagent(graphicID)
    local items = Items.FindByFilter({ Graphic = graphicID, RootContainer = Player.Serial })
    return (#items > 0) and #items or 0
end

-- Check if required reagents exist for a given healing spell
local function HasReagentsForHeal(spellName)
    if spellName == "Heal" then
        return CountReagent(REAGENT_GARLIC) > 0
           and CountReagent(REAGENT_GINSENG) > 0
           and CountReagent(REAGENT_SPIDERSILK) > 0
    elseif spellName == "GreaterHeal" then
        return CountReagent(REAGENT_GARLIC) > 0
           and CountReagent(REAGENT_GINSENG) > 0
           and CountReagent(REAGENT_SPIDERSILK) > 0
           and CountReagent(REAGENT_MANDRAKE) > 0
    end
    return false
end

-- Select the appropriate offensive spell based on the player's Magery skill
local function SelectOffensiveSpell()
    local magerySkill = Skills.GetValue("Magery")
    for _, spell in ipairs(SPELLBOOK) do
        if magerySkill >= spell.skillMin and magerySkill < spell.skillMax then
            return spell
        end
    end
    return SPELLBOOK[#SPELLBOOK]
end

-- Check if the player knows (has) the given spell
local function CanCast(spellName)
    if Spells.CanCast then
        return Spells.CanCast(spellName)
    end
    return true
end

-- Check if Meditation is ready (no cooldown)
local function CanMeditate()
    if Skills.GetCooldown then
        local cd = Skills.GetCooldown("Meditation")
        return (not cd) or (cd <= 0)
    end
    return true
end

-- Attempt to cast Meditation if ready
local function TryMeditate()
    if CanMeditate() and Player.Mana < Player.MaxMana then
        Messages.Overhead("Casting Meditation to recover mana...", COLOR_INFO, Player.Serial)
        Skills.Use("Meditation")
        Pause(100)  -- Brief pause to let the skill register
    end
end

-- Attempt to cast a healing spell on self
-- Returns true if cast was attempted, false if out of reagents or cannot cast
local function CastHealSpell()
    local magerySkill = Skills.GetValue("Magery")
    local healSpell = nil

    -- Ensure basic reagents for Heal exist
    if not (CountReagent(REAGENT_GARLIC) > 0
         and CountReagent(REAGENT_GINSENG) > 0
         and CountReagent(REAGENT_SPIDERSILK) > 0) then
        return false
    end

    -- Use GreaterHeal if mandrake present, skill ≥ 60, enough mana, and reagents exist
    if CountReagent(REAGENT_MANDRAKE) > 0
       and magerySkill >= 60
       and Player.Mana >= 18
       and CanCast("GreaterHeal")
       and HasReagentsForHeal("GreaterHeal") then
        healSpell = "GreaterHeal"
    else
        -- Otherwise, cast normal Heal if possible
        if Player.Mana >= 6 and CanCast("Heal") and HasReagentsForHeal("Heal") then
            healSpell = "Heal"
        else
            return false  -- Cannot cast any heal
        end
    end

    Messages.Overhead("Casting " .. healSpell .. " to heal...", COLOR_INFO, Player.Serial)
    Spells.Cast(healSpell)
    -- Wait up to 2 seconds for the targeting cursor, then target player
    if Targeting.WaitForTarget(2000) then
        Targeting.Target(Player.Serial)
    end
    Pause(DELAY_HEAL)

    -- Immediately attempt to meditate if Meditation is off cooldown
    TryMeditate()

    -- Check Journal for reagent failure
    if Journal.Contains("You lack the reagents") or Journal.Contains("You do not have enough reagents") then
        Messages.Overhead("Out of reagents for " .. healSpell .. "! Script stopping.", COLOR_ALERT, Player.Serial)
        return false
    end

    return true
end

-- Fully meditate until mana is max or player dies
local function MeditateToFull()
    Messages.Overhead("Mana critically low, meditating until full...", COLOR_INFO, Player.Serial)
    Skills.Use("Meditation")
    Pause(100)
    while Player.Mana < Player.MaxMana and not Player.IsDead do
        Pause(500)
    end
end

-- Proactively meditate on cooldown when mana > 50%
local function ProactiveMeditate()
    if Player.Mana > Player.MaxMana * MANA_MEDIATE_THRESHOLD then
        TryMeditate()
    end
end

-- === Main Loop ===
while true do
    -- Healing logic if AUTO_HEAL is enabled
    if AUTO_HEAL and (Player.Poisoned or Player.Hits <= HEALTH_THRESHOLD) then
        Messages.Overhead("Health low or poisoned, searching for bandages...", COLOR_INFO, Player.Serial)
        local bandage = FindBandage()
        if bandage then
            Messages.Overhead("Bandage found, healing self...", COLOR_HINT, Player.Serial)
            Player.UseObject(bandage.Serial)
            if Targeting.WaitForTarget(1000) then
                Targeting.Target(Player.Serial)
            end
            -- After bandage, attempt to meditate if ready
            TryMeditate()
            Pause(DELAY_HEAL)
        else
            -- No bandage, attempt magery heal
            Messages.Overhead("No bandages - using Heal/GreaterHeal...", COLOR_ALERT, Player.Serial)
            if not CastHealSpell() then
                return -- Stop if no basic heal reagents
            end
        end
        goto continue
    elseif not AUTO_HEAL and Player.Hits <= HEALTH_THRESHOLD then
        -- If AUTO_HEAL is disabled and health is too low, do not cast offensive spells
        Messages.Overhead("Health low but healing disabled!", COLOR_ALERT, Player.Serial)
        Pause(DELAY_LOOP)
        goto continue
    end

    -- Offensive spellcasting logic
    local spell = SelectOffensiveSpell()
    if not Player.Poisoned and Player.Hits > HEALTH_THRESHOLD then
        if Player.Mana >= spell.manaCost then
            -- Cast immediately if enough mana
            Messages.Overhead("Casting " .. spell.name .. " (cost: " .. spell.manaCost .. " mana)...", COLOR_INFO, Player.Serial)
            Spells.Cast(spell.name)
            if Targeting.WaitForTarget(2000) then
                Targeting.Target(Player.Serial)
            end
            Pause(DELAY_CAST)
            -- Do not mediate now; next iteration will handle meditation
            goto continue
        elseif Player.Mana < Player.MaxMana * MANA_LOW_THRESHOLD then
            -- Mana critically low: meditate to full
            MeditateToFull()
            goto continue
        else
            -- Mana insufficient for chosen spell but above low threshold: proactive meditate if >50%
            ProactiveMeditate()
            Pause(DELAY_LOOP)
            goto continue
        end
    else
        Messages.Overhead("Waiting for health to recover or disabled healing...", COLOR_ALERT, Player.Serial)
    end

    -- Idle pause
    Messages.Overhead("Idle: no action required, looping...", COLOR_INFO, Player.Serial)
    Pause(DELAY_LOOP)

    ::continue::
end
