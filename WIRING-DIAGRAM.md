# Optoisolated Dual-FTDI USB-to-UART Bridge (6N137)

## 1. Overview & Architecture

This design connects two physical FTDI USB-to-UART adapters (or FT232 chips) back-to-back with complete **galvanic electrical isolation** using two high-speed **6N137** optocouplers.

### Key Characteristics

* **True Galvanic Isolation:** Side A and Side B share **no common ground** and **no power lines**. Each side is powered entirely by its own USB host port ($V_{CC\_A} / GND\_A$ vs $V_{CC\_B} / GND\_B$).
* **High Baud Rates:** 6N137 supports data rates up to **10 MBd** (easily handles 115200, 230400, 460800, 921600 baud and beyond with sharp edge transitions).
* **Non-Inverting UART Logic:** Uses active-low cathode driving so UART Idle (HIGH) leaves the LED OFF and output pulled HIGH, matching standard UART idle states without extra inverter ICs.

---

## 2. Complete ASCII Schematic & Wiring Diagram

```text
========================================================================================================================
                                         GALVANIC ISOLATION BARRIER
  SIDE A: HOST SYSTEM (USB A)                                                     SIDE B: TARGET SYSTEM (USB B)
  Domain: VCC_A (5V / 3.3V), GND_A                                                Domain: VCC_B (5V / 3.3V), GND_B
========================================================================================================================

========================================================================================================================
CHANNEL 1: Host Transmit (TXD_A)  -->  Target Receive (RXD_B)  [Optocoupler U1: 6N137]
========================================================================================================================

  SIDE A: HOST DOMAIN (VCC_A, GND_A)                      SIDE B: TARGET DOMAIN (VCC_B, GND_B)
  ----------------------------------                      ------------------------------------

  FTDI A [VCC] ---> [R1: 330R] ---> Pin 2 [ANODE]         FTDI B [VCC] ---+---> Pin 8 [VCC] (IC Power)
                                    (U1: 6N137)                           +---> Pin 7 [VE]  (Enable - Active High)
                                                                          +---> [R2: 1k Pull-up] (Top)
  FTDI A [TXD] -------------------> Pin 3 [CATH]                          +---> [C1: 0.1uF Cap]  (Top)
                                    (U1: 6N137)
                                                          Pin 6 [VO] -----+---> [R2: 1k Pull-up] (Bottom)
  Pins 1, 4: NC (No internal connection)                  (Open-Collector)+---> FTDI B [RXD]     (Serial In)

                                                          FTDI B [GND] ---+---> Pin 5 [GND] (IC Ground)
                                                                          +---> [C1: 0.1uF Cap]  (Bottom)


  Visual Schematic (U1):
  ----------------------
    [FTDI A: VCC]                                            [FTDI B: VCC]
         |                                                         |
     [R1: 330R]               +--------------------+---------------+--------------------+
         |                    |                    |               |                    |
         v                    v                    v               |                    |
    Pin 2 (Anode)        Pin 8 (VCC)          Pin 7 (VE)      [C1: 0.1uF]            [R2: 1k]
  +------------------------------------------------------+    (Bypass Cap)           (Pull-Up)
  |                      U1: 6N137                       |         |                    |
  |                                                      |         |                    |
  |   (LED Input Side)          (Detector Output Side)   |         |                    |
  |                                                      |         |                    |
  | Pin 3 (Cathode)                           Pin 6 (VO) |---------|--------------------+-----> [FTDI B: RXD]
  +------------------------------------------------------+         |
         ^                                         |               |
         |                                    Pin 5 (GND)          |
    [FTDI A: TXD]                                  |               |
                                                   +---------------+--------------------------> [FTDI B: GND]
                                                                                                (GND_B)


========================================================================================================================
CHANNEL 2: Target Transmit (TXD_B)  -->  Host Receive (RXD_A)  [Optocoupler U2: 6N137]
========================================================================================================================

  SIDE A: HOST DOMAIN (VCC_A, GND_A)                      SIDE B: TARGET DOMAIN (VCC_B, GND_B)
  ----------------------------------                      ------------------------------------

  FTDI A [VCC] ---+---> Pin 8 [VCC] (IC Power)            FTDI B [VCC] ---> [R3: 330R] ---> Pin 2 [ANODE]
                  +---> Pin 7 [VE]  (Enable - Active High)                                  (U2: 6N137)
                  +---> [R4: 1k Pull-up] (Top)
                  +---> [C2: 0.1uF Cap]  (Top)            FTDI B [TXD] -------------------> Pin 3 [CATH]
                                                                                            (U2: 6N137)
  Pin 6 [VO] -----+---> [R4: 1k Pull-up] (Bottom)
  (Open-Collector)+---> FTDI A [RXD]     (Serial In)      Pins 1, 4: NC (No internal connection)

  FTDI A [GND] ---+---> Pin 5 [GND] (IC Ground)
                  +---> [C2: 0.1uF Cap]  (Bottom)


  Visual Schematic (U2):
  ----------------------
    [FTDI A: VCC]                                            [FTDI B: VCC]
         |                                                         |
    +----+---------------+--------------------+               [R3: 330R]
    |                    |                    |                    |
    |               [C2: 0.1uF]          Pin 7 (VE)                v
 [R4: 1k]           (Bypass Cap)              |               Pin 2 (Anode)
 (Pull-Up)               |                    v           +--------------------------------------+
    |                    |               Pin 8 (VCC)      |              U2: 6N137               |
    |                    |     +---------------------+    |                                      |
    |                    |     |      U2: 6N137      |    | (LED Input Side)                     |
    |                    |     |                     |    |                                      |
    +--------------------|-----| Pin 6 (VO)          |    |                      Pin 3 (Cathode) |<-- [FTDI B: TXD]
    |                    |     +---------------------+    +--------------------------------------+
    v                    |                |
 [FTDI A: RXD]           |           Pin 5 (GND)
                         |                |
                         +----------------+----------------------------------------> [FTDI A: GND]
                                                                                     (GND_A)
========================================================================================================================
```

---

## 3. Optocoupler Pin Connections Reference Table

### Optocoupler U1 (Channel 1: TX_A $\rightarrow$ RX_B)

| Pin # | 6N137 Pin Name | Function | Connects To | Voltage Domain |
| :--- | :--- | :--- | :--- | :--- |
| **Pin 1** | NC | No internal connection | *Leave unconnected* | N/A |
| **Pin 2** | Anode | Input LED (+) | Resistor `R1` ($330\,\Omega$) $\rightarrow$ `VCC_A` | Side A (Host) |
| **Pin 3** | Cathode | Input LED ($-$) | `TXD_A` (FTDI A TX output pin) | Side A (Host) |
| **Pin 4** | NC | No internal connection | *Leave unconnected* | N/A |
| **Pin 5** | GND | Output Ground | `GND_B` (FTDI B Ground) | Side B (Target) |
| **Pin 6** | VO | Open-Collector Output | Pull-up `R2` ($1\,\text{k}\Omega$) to `VCC_B` & `RXD_B` | Side B (Target) |
| **Pin 7** | VE | Output Enable (Active High) | `VCC_B` (Tied directly to Pin 8) | Side B (Target) |
| **Pin 8** | VCC | Output Power (4.5V–5.5V) | `VCC_B` (FTDI B 5V output) | Side B (Target) |
| **C1** | Bypass Capacitor | $0.1\,\mu\text{F}$ Ceramic | Directly between Pin 8 ($V_{CC}$) and Pin 5 ($GND$) | Side B (Target) |

---

### Optocoupler U2 (Channel 2: TX_B $\rightarrow$ RX_A)

| Pin # | 6N137 Pin Name | Function | Connects To | Voltage Domain |
| :--- | :--- | :--- | :--- | :--- |
| **Pin 1** | NC | No internal connection | *Leave unconnected* | N/A |
| **Pin 2** | Anode | Input LED (+) | Resistor `R3` ($330\,\Omega$) $\rightarrow$ `VCC_B` | Side B (Target) |
| **Pin 3** | Cathode | Input LED ($-$) | `TXD_B` (FTDI B TX output pin) | Side B (Target) |
| **Pin 4** | NC | No internal connection | *Leave unconnected* | N/A |
| **Pin 5** | GND | Output Ground | `GND_A` (FTDI A Ground) | Side A (Host) |
| **Pin 6** | VO | Open-Collector Output | Pull-up `R4` ($1\,\text{k}\Omega$) to `VCC_A` & `RXD_A` | Side A (Host) |
| **Pin 7** | VE | Output Enable (Active High) | `VCC_A` (Tied directly to Pin 8) | Side A (Host) |
| **Pin 8** | VCC | Output Power (4.5V–5.5V) | `VCC_A` (FTDI A 5V output) | Side A (Host) |
| **C2** | Bypass Capacitor | $0.1\,\mu\text{F}$ Ceramic | Directly between Pin 8 ($V_{CC}$) and Pin 5 ($GND$) | Side A (Host) |

---

## 4. Theory of Operation & Logic Level Truth Table

Standard UART signals idle in the **HIGH (Mark)** state and transition **LOW (Space)** for start bits and logic `0`s.

```text
+-----------+----------------+----------------+----------------+-------------------+
| TXD State | LED Current IF | Opto LED State | VO Output (OC) | RXD Voltage Level |
+-----------+----------------+----------------+----------------+-------------------+
| HIGH (1)  | 0 mA (No drop) | OFF            | High-Z (Open)  | HIGH (VCC pull-up)|  <-- UART Idle
| LOW  (0)  | ~10 mA (Sunk)  | ON             | Sunk to GND    | LOW (0V Ground)   |  <-- UART Active
+-----------+----------------+----------------+----------------+-------------------+
```

* **No Inverter Needed:** Driving the LED cathode directly from the FTDI TX pin eliminates the need for external inverters or transistors.
* **Speed:** 6N137 incorporates a Faraday shield for $>10\text{ kV}/\mu\text{s}$ Common Mode Transient Immunity (CMTI) and has typical propagation delays of only $\approx 50\text{ ns}$.

---

## 5. Resistor Sizing Calculations

### 1. LED Resistors (`R1`, `R3`)

* **LED Forward Voltage ($V_F$):** $\approx 1.4\text{ V}$
* **Target Forward Current ($I_F$):** $\approx 10\text{ mA}$ (Recommended for 6N137 high-speed operation)
* **For 5.0 V Supply:**
  $$R = \frac{V_{CC} - V_F}{I_F} = \frac{5.0\text{ V} - 1.4\text{ V}}{10\text{ mA}} = \frac{3.6\text{ V}}{0.010\text{ A}} = 360\,\Omega \implies \mathbf{330\,\Omega\text{ (standard)}}$$
  *(With $330\,\Omega$, $I_F = 10.9\text{ mA}$, well within FTDI's 24mA sink rating).*
* **For 3.3 V Supply (Optional 3.3V variant like HCPL-0600):**
  $$R = \frac{3.3\text{ V} - 1.4\text{ V}}{7.5\text{ mA}} = \frac{1.9\text{ V}}{0.0075\text{ A}} = 253\,\Omega \implies \mathbf{220\,\Omega\text{ or }270\,\Omega}$$

### 2. Output Pull-Up Resistors (`R2`, `R4`)

* **Value:** $\mathbf{1\,\text{k}\Omega}$ (or $470\,\Omega$ for $\ge 1\text{ MBd}$).
* $1\,\text{k}\Omega$ ensures fast rise-time on the open-collector output ($\le 25\text{ ns}$) while consuming only $5\text{ mA}$ when pulling LOW.

---

## 6. Bill of Materials (BOM)

| Item | Qty | Reference | Value / Part | Description | Package / Footprint |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | 2 | `U1`, `U2` | **6N137** | High-Speed 10 MBd Optocoupler (Vishay / Broadcom / Lite-On / Toshiba) | DIP-8 or SOIC-8 |
| **2** | 2 | `R1`, `R3` | **$330\,\Omega$** | $1/4\text{W}$, 5% or 1% Carbon Film / Metal Film Resistor | Through-hole (Axial) or SMD 0805 |
| **3** | 2 | `R2`, `R4` | **$1\,\text{k}\Omega$** | $1/4\text{W}$, 5% or 1% Carbon Film / Metal Film Resistor | Through-hole (Axial) or SMD 0805 |
| **4** | 2 | `C1`, `C2` | **$0.1\,\mu\text{F}$ (100nF)** | 50V X7R Ceramic Decoupling Capacitor (**Crucial: place near pin 8 & 5**) | Through-hole (Radial) or SMD 0805 |
| **5** | 2 | `MOD1`, `MOD2` | **FT232RL / FT232H / FT230X** | USB-to-UART Serial Adapter Breakout Boards (Provides VCC, GND, TX, RX) | USB Module / PCB Header |
| **6** | 2 | `C3`, `C4` (Opt.) | **$10\,\mu\text{F}$** | 16V Tantalum or Electrolytic Bulk Capacitor across VCC/GND on each side | Radial / SMD (Optional) |
| **7** | 1 | Breadboard/PCB | **Perfboard / Custom PCB** | Keep $\ge 5\text{ mm}$ physical creepage clearance between Side A and Side B | Circuit Board |

---

## 7. Practical Assembly Tips

1. **Isolation Clearance (Creepage Distance):**
   Do not run Ground A or Power A traces anywhere near Ground B or Power B traces. Keep at least **$5\text{ mm}$ to $8\text{ mm}$ of clearance** (creepage slot) beneath the center of the 6N137 chips.
2. **Decoupling is Mandatory:**
   The 6N137 contains high-gain active output circuitry. Omitting `C1` and `C2` ($0.1\,\mu\text{F}$) or placing them far from the IC pins will cause output oscillation and high error rates.
3. **Power Source:**
   * Take `VCC_A` and `GND_A` directly from the 5V and GND pins of FTDI Module A.
   * Take `VCC_B` and `GND_B` directly from the 5V and GND pins of FTDI Module B.
