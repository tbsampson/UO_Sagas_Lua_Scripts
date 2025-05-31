--[[
                                             __             __    
     	  ___ ________ ___ _  ___  ___ ____ / /  ___  ___  / /____
\\\\---- / _ `/ __/ _ `/  ' \/ _ \/ _ `(_-</ _ \/ _ \/ _ \/ __(_-< ----\
////---- \_, /_/  \_,_/_/_/_/ .__/\_,_/___/_//_/\___/\___/\__/___/ ----/
        /___/              /_/
Magery Trainer v 1.3

Requirements:
------
Healing/Anatomy (Train at npc to ~30 is fine)
A few hundred bandages, plenty of reagents (see list below), and a safe place to macro

Usage:
------
This script automates your magery training in UO Sagas. 
It will automatically cast spells on your character then heal using bandages.


The script selects spells dynamically based on your Magery skill level,
from Magic Arrow to Flamestrike. It also uses Meditation to recover mana 
when it falls below the threshold (10 mana). 

Make sure to have plenty of bandages and the required spell reagents
in your backpack. The script runs in an infinite loop, so you can start
it and let it handle the training automatically.

Reagents required for each spell:
---------------------------------
  • Magic Arrow:  Sulfurous Ash
  • Fireball:     Black Pearl
  • Lightning:    Mandrake Root, Sulfurous Ash
  • Energy Bolt:  Black Pearl, Nightshade
  • Flamestrike:  Spider's Silk, Sulfurous Ash

Note: This script assumes you have enough reagents to sustain casting and that you are in a safe location for training.

]]--

-- === Configuration Constants ===
local GRAPHIC_BANDAGE = 0x0E21       -- Item ID for bandages
local DELAY_HEAL = 14000             -- Delay after bandaging (ms)
local DELAY_CAST = 1500              -- Delay after casting (ms)
local DELAY_LOOP = 1000              -- Delay between loop iterations (ms)
local DELAY_MEDITATE = 10000         -- Meditation duration (ms)
local HEALTH_THRESHOLD = 65          -- Heal if health is below or equal to this
local MANA_MINIMUM = 10              -- Minimum mana to attempt meditation

-- === Spell Definitions ===
local SPELLBOOK = {
    { name = "MagicArrow",   skillMin = 0,   skillMax = 30,  manaCost = 4 },
    { name = "Fireball",     skillMin = 30,  skillMax = 50,  manaCost = 9 },
    { name = "Lightning",    skillMin = 50,  skillMax = 70,  manaCost = 11 },
    { name = "EnergyBolt",   skillMin = 70,  skillMax = 90,  manaCost = 20 },
    { name = "Flamestrike",  skillMin = 90,  skillMax = 100, manaCost = 40 }
}

-- === Helper Functions ===

-- Find the first bandage in the player's backpack
function FindBandage()
    local inventory = Items.FindByFilter({ RootContainer = Player.Serial })
    for _, item in ipairs(inventory) do
        if item and item.Graphic == GRAPHIC_BANDAGE then
            return item
        end
    end
    return nil
end

-- Select the appropriate spell based on the player's magery skill
function SelectSpell()
    local magerySkill = Skills.GetValue("Magery")
    for _, spell in ipairs(SPELLBOOK) do
        if magerySkill >= spell.skillMin and magerySkill < spell.skillMax then
            return spell
        end
    end
    return SPELLBOOK[#SPELLBOOK] -- Default to highest spell if no match
end

-- === Main Loop ===
while true do
    -- Healing logic: Use bandage if poisoned or low on health
    if Player.Poisoned or Player.Hits <= HEALTH_THRESHOLD then
        local bandage = FindBandage()
        if bandage then
            Player.UseObject(bandage.Serial)
            if Targeting.WaitForTarget(1000) then
                Targeting.Target(Player.Serial)
            end
            Skills.Use("Meditation")
            Pause(DELAY_HEAL)
        end
        goto continue
    end

    -- Offensive spellcasting logic
    local spell = SelectSpell()
    if not Player.Poisoned and Player.Hits > HEALTH_THRESHOLD and Player.Mana >= spell.manaCost then
        if Player.Mana < MANA_MINIMUM then
            Skills.Use("Meditation")
            Pause(DELAY_MEDITATE)
        end

        Spells.Cast(spell.name)
        if Targeting.WaitForTarget(2000) then
            Targeting.Target(Player.Serial)
        end
        Pause(DELAY_CAST)
        goto continue
    end

    -- Idle pause
    Pause(DELAY_LOOP)

    -- Continue label for flow control
    ::continue::
end
