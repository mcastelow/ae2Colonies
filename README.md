# ⚡ AE2 Colony Logistics (ATM10)

A sleek, futuristic ComputerCraft: Tweaked script optimized for **All the Mods 10 (Minecraft 1.21.1)** [8.1+]. This system establishes a real-time quantum handshake between an **Applied Energistics 2 (AE2)** network and a **MineColonies** town logistics grid via **Advanced Peripherals**. 

It monitors your citizen construction requests, matches them against your digital ME cells, automatically processes partial or full deliveries, and reports all states onto a high-visibility terminal dashboard.

---

## 🛰️ Physical Hardware Topology

For the script to scan, route, and map peripheral addresses correctly, your blocks must be laid out in the exact orientation described below.

### Visual Blueprint (Top-Down View)

[ 5 x 3 MONITOR WALL ]  <-- Placed directly ABOVE the Advanced Computer
         [TOP]
           │
[Colony Integrator] ➔ [Advanced Computer] ➔ [ME Bridge] ➔ [Ender Chest]
      [LEFT]             [MIDDLE]          [RIGHT]       [FRONT of Bridge]
                                              │
                                            [BACK]
                                              └── [Wireless ME Terminal]

### Component Details
* **Advanced Computer (Center):** The host brain running the kernel.
* **Monitor Wall (5x3 Grid):** Placed directly on top of the Advanced Computer. Keep text scale at 1 for the tech panel array.
* **Colony Integrator (Left):** Placed directly to the left of the computer. Note: This block must sit physically within your MineColonies town borders.
* **ME Bridge (Right):** Placed directly to the right of the computer.
* **Wireless ME Terminal (Back of Bridge):** Connects the ME Bridge wirelessly back to your primary AE2 mainframe.
* **Ender Chest (Front of Bridge):** Placed directly in front of the ME Bridge block. This serves as the physical routing drop-off point where items are ejected. Ensure your colony Couriers have access to this chest (or route it to a colony Postbox).

---

## 💾 Installation & Mainframe Deployment

1. Access the terminal command line of your in-game Advanced Computer.
2. Run the following built-in HTTP download command to pull the kernel raw script directly into your local directory:

wget https://raw.githubusercontent.com/mcastelow/ae2Colonies/refs/heads/main/ae2-colony.lua kernel.lua

3. To set the system to initialize automatically whenever the chunk loads or the computer restarts, create a boot configuration file:

echo kernel.lua > startup.lua

4. Fire up the dashboard array by running:

kernel

---

## 🎛️ Diagnostic State Readouts

The dashboard utilizes an advanced cyberpunk color palette to represent network states:
* ▶ ROUTING (Plasma Green): The item is detected in the ME network and is being safely pushed to the Ender Chest.
* ⚠ DEPLETED (Quantum Amber): Your ME network contains a partial amount of the requested resources. The kernel dumps whatever is left and flags the deficit.
* ✖ VOID (Critical Red): The item is entirely missing from your storage matrix.
* [⚡] (Glowing Magenta): Flashes in the header bar during active polling ticks.
