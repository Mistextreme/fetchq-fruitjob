# FetchQ Logistics: Agricultural Transport System

<div align="center">
  <i>An advanced, multi-framework logistical simulation tailored for high-density environments.</i>
</div>

---

FetchQ Logistics provides a deeply integrated, highly optimized agricultural transport career path for your server's economy. Built with scalability and absolute performance at its core, this package provides seamless roleplay opportunities for both solo operators and organized syndicates.

### Core Architecture & Capabilities

* **Adaptive Job Modes:**
  * **Independent Operation (Solo):** Operators make risk assessments, coordinate NPC laborers for automated loading procedures, and execute direct end-to-end deliveries.
  * **Syndicate Operation (2-4 Players):** Introduces a collaborative fulfillment pipeline. Teams process crates manually, load the designated fleet transport, proceed through the weighbridge system, execute a risk assessment, and distribute to the finalized destination.
* **Risk & Documentation Matrix:** Engage in legitimate business operations utilizing verified transit logs (`green_document`), or bypass regulations for higher yields via hazardous routes (`red_document`).
* **Micro-Optimized Performance Footprint:** Engineered specifically for high-capacity environments (400+ concurrent clients). Abandons PolyZone arrays in favor of optimized native distance calculations and dynamic thread throttling.
* **Modular Compatibility:** Seamlessly integrates with the holy trinity of frameworks (`qb-core`, `qbox`, `es_extended`) and leading interaction engines (`ox_target`, `qb-target`).

---

## Deployment Sequence

Follow the proceeding deployment steps to integrate the logistics framework into your production environment.

### 1. Item Declaration
Navigate to your active inventory configuration (e.g., `qb-core/shared/items.lua` or `ox_inventory/data/items.lua`) and define the following crucial network items.

<details>
<summary>View Lua Definitions (Click to Expand)</summary>

```lua
['green_document'] = {
    ['name'] = 'green_document',
    ['label'] = 'Legal Transport Document',
    ['weight'] = 100,
    ['type'] = 'item',
    ['image'] = 'green_document.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'Legal fruit transport document - Approved'
},
['red_document'] = {
    ['name'] = 'red_document',
    ['label'] = 'Unregistered Transport Document',
    ['weight'] = 100,
    ['type'] = 'item',
    ['image'] = 'red_document.png',
    ['unique'] = true,
    ['useable'] = true,
    ['shouldClose'] = true,
    ['combinable'] = nil,
    ['description'] = 'Unregistered fruit transport document - Risky!'
}
```
</details>

*Note: Ensure the required raster images (`green_document.png`, `red_document.png`) are provisioned in your corresponding UI image directory before initializing.*

### 2. Mounting the Resource
Inject the resource declaration into your primary initialization process.
```bash
# Add this command directive securely within your environment configuration (server.cfg)
ensure fetchq-fruitjob
```

### 3. Variables & Parameter Calibration
All modifiable state behaviors and coordinates are housed within `config.lua` at the root of the repository.

* **Pedestrian & Spatial Arrays:** Modulate origin anchors using `Config.DepotNPC` and `Config.Farm`.
* **Transport Matrices:** Adjust fleet specifications via `Config.Truck.model`.
* **Syndicate Logistics:** Define payload minimums through `Config.GroupMode.crateTarget`.
* **Economic Variables:** Modulate output streams and reward multipliers via `Config.Payment.safe` and `Config.Payment.risky`.
* **Distribution Graph:** Map out end-routes inside `Config.DeliveryPoints.locations`.

### Technical Dependencies
To ensure unhindered client-server synchronization, establish that the following dependencies are installed:
- Framework Ecosystem (`qb-core`, `qbx_core`, or `es_extended`)
- `ox_lib` (Utilized for UI rendering & data contexts)
- Supported Target Engine (`ox_target` or `qb-target`)
