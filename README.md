# grampashoots UO Sagas Lua Scripts

A curated collection of Lua scripts and utilities by grampashoots designed specifically for automating and enhancing gameplay in **Ultima Online: Sagas**. Whether you’re a seasoned developer or a new scripter, this repository aims to provide clear, well-organized, and reusable code snippets to streamline common tasks—such as skinning, corpse looting, magery training, and more—within the UO Sagas environment.

---

## Table of Contents

1. [Overview](#overview)  
2. [Features](#features)  
3. [Prerequisites](#prerequisites)  
4. [Installation](#installation)  
5. [Usage](#usage)  
6. [Example Scripts](#example-scripts)  
7. [Folder Structure](#folder-structure)  
8. [Contributing](#contributing)  
9. [License](#license)  
10. [Contact & Support](#contact--support)  

---

## Overview

Ultima Online: Sagas (UO Sagas) uses a Lua-based scripting engine to allow players to automate repetitive tasks, improve efficiency, and create custom macros. Over time, as new features are added to the client and server, script syntax and available API calls may change. This repository collects community-tested Lua snippets, helper functions, and example macros that:

- Perform common in-game tasks (e.g., skinning corpses, auto-healing, resource gathering).  
- Demonstrate best practices for targeting, timing, and error handling in UO Sagas’ Lua environment.  
- Provide modular, reusable utilities that can be adapted to your own gameplay or extended for custom functionality.  

Each script is annotated with comments to explain its purpose, required reagents (where applicable), and how to integrate it into your local client’s script folder.

---

## Features

- **Skinning & Looting Utilities**  
  - Automatically identify nearby corpses (filtered by graphic IDs).  
  - Attempt to skin or loot corpses within a specified range, with retry logic and basic logging.  

- **Magery Training Helpers**  
  - Scripts to cast spells (e.g., Peacemaking, Cure, Heal) until a specified skill threshold is reached.  
  - Integrated reagent checks (e.g., Black Pearl, Garlic, Sulfurous Ash, Ginseng, Mandrake Root).  

- **Bandaging & Healing Macros**  
  - Monitor player HP percentage and automatically apply bandages or cast Cure spells when health falls below a threshold.  
  - Adjustable delays (`HEAL_DELAY`, `CAST_DELAY`) and customizable bandage types.  

- **Targeting & Movement (where possible) Routines**  
  - Generic functions for finding items in backpack by graphic ID or type.  
  - Self-target logic, walk-to-target commands, and simple pathfinding placeholders.  

- **Inventory Management**  
  - Helper functions to locate reagents, weapons, or tools in the player’s backpack.  
  - Sample “GetBackpackItem” function that checks `item.RootContainer == Player.Serial`.  

- **Extensible Framework**  
  - All scripts follow a consistent naming convention (e.g., `scriptname.lua`) and use descriptive comments.  
  - A centralized `utils.lua` file provides shared functions (e.g., `FindFirstItemByType`, `WaitForTarget`, `CastSpellIfAvailable`).  

---

## Prerequisites

1. **Ultima Online: Sagas Client**  
   - Ensure you have the latest UO Sagas client installed and updated.  
   - Verify that the Lua scripting engine is enabled in your client settings.

2. **Basic Lua Knowledge**  
   - Familiarity with Lua syntax (`function`, `local`, tables, loops).  
   - Understanding of UO Sagas’ API calls (e.g., `Spells.Cast`, `Targeting.WaitForTarget`, `Items.FindByType`).

3. **Script Directory Setup**  
   - Determine the folder where your UO Sagas client loads `.lua` files (often in a “Scripts” or “Macros” subfolder under your game directory).  
   - Create a dedicated subfolder (e.g., `UO_Sagas_Lua_Scripts`) to keep these examples separate from your personal macros.

---

## Installation

1. **Clone or Download This Repository**  
   ```bash
   git clone https://github.com/<your-username>/UO_Sagas_Lua_Scripts.git
