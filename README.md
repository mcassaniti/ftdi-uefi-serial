# Optoisolated Back-to-Back FTDI USB Serial for Headless UEFI & Kernel Access

[![Tianocore EDK II](https://img.shields.io/badge/Tianocore-EDK%20II-blue.svg)](https://github.com/tianocore/edk2)
[![Upstream PR #1047](https://img.shields.io/badge/PR-Fixes%20%231047-green.svg)](https://github.com/tianocore/edk2-platforms/pull/1047)
[![Upstream PR #1048](https://img.shields.io/badge/PR-Feature%20%231048-orange.svg)](https://github.com/tianocore/edk2-platforms/pull/1048)
[![License: BSD-2-Clause-Patent](https://img.shields.io/badge/License-BSD--2--Clause--Patent-brightgreen.svg)](LICENSE)

A complete hardware schematic, patchset, and containerized build system for establishing a high-speed, **galvanically isolated back-to-back FTDI USB-to-UART bridge** that enables interactive headless serial console access across the entire boot lifecycle: **UEFI Shell**, **Bootloader (systemd-boot / GRUB)**, and the **Linux Kernel**.

---

## Table of Contents

1. [Why This Project Exists](#1-why-this-project-exists)
2. [How It Works](#2-how-it-works)
3. [Hardware Architecture & Isolation](#3-hardware-architecture--isolation)
4. [EDK II Driver Fixes & Features](#4-edk-ii-driver-fixes--features)
5. [Building the Driver (Docker)](#5-building-the-driver-docker)
6. [Deployment & Usage](#6-deployment--usage)
7. [Repository Structure](#7-repository-structure)

---

## 1. Why This Project Exists

Modern x86_64 and AArch64 systems (servers, NUCs, desktops, laptops) increasingly lack legacy RS-232 16550 UART COM ports. While USB-to-UART bridges (such as FTDI FT232R/FT232H) are cheap, ubiquitous, and support speeds up to **3–12 MBaud**, standard UEFI firmware does **not** attach USB serial adapters to the system console by default.

Furthermore, connecting two separate computers directly over unisolated UART lines risks **ground loops, voltage potential differences, and electrical damage** if one system is power-cycled or on a different AC circuit.

### What this project delivers:

* **True Galvanic Isolation:** Optical isolation barrier using high-speed **6N137** optocouplers (10 MBd) with independent power domains.
* **Full UEFI Console Handshake:** Patched `FtdiUsbSerialDxe.efi` UEFI driver that registers console protocols and connects `ConSplitterDxe`, enabling interactive boot menus (e.g. `systemd-boot`) and early UEFI output without firmware NVRAM pre-configuration.
* **Zero Host Tool Dependencies:** 100% reproducible Docker build environment compiling the driver directly from EDK II sources.

---

## 2. How It Works

```text
+---------------------+                                             +---------------------+
|   HOST COMPUTER     |                                             |   TARGET SYSTEM     |
| (Developer Laptop / |                                             |  (Headless Server / |
|   Debug Station)    |                                             |    QEMU / Testbed)  |
|                     |                                             |                     |
|  /dev/ttyUSB0       |                                             |  UEFI / Linux Host  |
|  (picocom / screen) |                                             |                     |
+----------+----------+                                             +----------+----------+
           | USB Cable (5V / GND_A)                                            | USB Cable (5V / GND_B)
           v                                                                   v
+---------------------+                                             +---------------------+
|   FTDI ADAPTER A    |                                             |   FTDI ADAPTER B    |
|  (FT232RL / FT232H) |                                             |  (FT232RL / FT232H) |
+----------+----------+                                             +----------+----------+
           |                                                                   |
           |   TXD_A ------------------> [ U1: 6N137 ] -----------------> RXD_B|
           |                             (Optical)                             |
           |   RXD_A <------------------ [ U2: 6N137 ] <----------------- TXD_B|
           |                             (Optical)                             |
           |                                                                   |
           |    [ Domain A: VCC_A, GND_A ]     ||   [ Domain B: VCC_B, GND_B ] |
           +-----------------------------------++------------------------------+
                                      GALVANIC BARRIER
                                    (No common Ground)
```

1. **Target Side (Side B):** When the target powers on, the UEFI environment loads `FtdiUsbSerialDxe.efi`.
2. **Driver Binding:** The driver binds to FTDI Adapter B, establishes the `EFI_SERIAL_IO_PROTOCOL`, binds `TerminalDxe` (producing `SimpleTextIn` and `SimpleTextOut`), and attaches `ConSplitterDxe`.
3. **Interactive Boot:** The user interacts with bootloader menus (`systemd-boot`, GRUB, EFI Shell) over the serial terminal.
4. **Kernel Handover:** When the Linux kernel boots with `console=ttyUSB0,115200n8`, the kernel's `ftdi_sio` driver assumes control of FTDI Adapter B seamlessly.
5. **Host Side (Side A):** The developer connects via `picocom -b 115200 /dev/ttyUSB0` on their workstation with full electrical isolation.

---

## 3. Hardware Architecture & Isolation

Detailed schematics, BOM, resistor calculations, and pinout tables are located in [**`WIRING-DIAGRAM.md`**](WIRING-DIAGRAM.md).

### Summary Specifications

* **Optocoupler:** Dual **6N137** (High-Speed 10 MBd logic output with Faraday shield, $>10\text{ kV}/\mu\text{s}$ CMTI).
* **Signaling:** Active-low LED cathode driving (UART Idle HIGH = LED OFF = Output pulled HIGH). No external inverter ICs required.
* **Power:**
  * Side A powered by Host USB ($V_{CC\_A} = 5\text{V}$, $GND\_A$).
  * Side B powered by Target USB ($V_{CC\_B} = 5\text{V}$, $GND\_B$).
  * **$GND\_A$ and $GND\_B$ are completely isolated.**
* **Components Required:**
  * 2x 6N137
  * 2x $330\,\Omega$ resistors ($R_{LED}$)
  * 2x $1\,\text{k}\Omega$ resistors ($R_{pullup}$)
  * 2x $0.1\,\mu\text{F}$ ceramic bypass capacitors
  * 2x FTDI USB breakout boards at 5V

---

## 4. EDK II Driver Fixes & Features

The upstream Tianocore `OptionRomPkg/FtdiUsbSerialDxe` driver historically suffered from three critical bugs and lacked automatic console integration. This repository includes the following patches (submitted upstream to `tianocore/edk2-platforms`):

| Patch File | Upstream PR | Description |
| :--- | :--- | :--- |
| [`0001-Drivers-OptionRomPkg-Fix-zero-length-USB-control-req.patch`](patches/0001-Drivers-OptionRomPkg-Fix-zero-length-USB-control-req.patch) | [PR #1047](https://github.com/tianocore/edk2-platforms/pull/1047) | **Bug Fix:** Changes zero-length USB control requests from `EfiUsbDataOut`/`EfiUsbDataIn` to `EfiUsbNoData` with `NULL` data buffer per UEFI Spec Section 14.2.2. Prevents status `EFI_INVALID_PARAMETER` failures. |
| [`0002-Drivers-OptionRomPkg-Fix-FlowControl-device-path-in-.patch`](patches/0002-Drivers-OptionRomPkg-Fix-FlowControl-device-path-in-.patch) | [PR #1047](https://github.com/tianocore/edk2-platforms/pull/1047) | **Bug Fix:** Appends `UART_FLOW_CONTROL_DEVICE_PATH` with `gEfiUartDevicePathGuid` only when flow control is configured, avoiding corrupt device path nodes with all-zero GUIDs. |
| [`0003-Drivers-OptionRomPkg-Increase-FTDI_TIMEOUT-for-virtu.patch`](patches/0003-Drivers-OptionRomPkg-Increase-FTDI_TIMEOUT-for-virtu.patch) | [PR #1047](https://github.com/tianocore/edk2-platforms/pull/1047) | **Tuning:** Increases `FTDI_TIMEOUT` from 16ms to 50ms ($3\times$ hardware latency timer) to tolerate hypervisor/host scheduling jitter without dropping characters. |
| [`0004-Drivers-OptionRomPkg-Auto-attach-console-protocols-i.patch`](patches/0004-Drivers-OptionRomPkg-Auto-attach-console-protocols-i.patch) | [PR #1048](https://github.com/tianocore/edk2-platforms/pull/1048) | **Feature:** Adds `PcdFtdiAutoAttachConsole` (default `TRUE`) to connect `TerminalDxe`, install `gEfiConsoleInDeviceGuid` / `gEfiConsoleOutDeviceGuid` on terminal child handles, and connect `ConSplitterDxe`. Put plainly, whenever the FTDI device is initialized, the serial console is automatically connected to system input/output. Normally, UEFI requires console ports to be statically pre-configured in firmware NVRAM during early boot. |

---

## 5. Building the Driver (Docker)

A turnkey Docker build script compiles the standalone `.efi` binary from pristine EDK II sources with all patches applied.

```bash
# Clone this repository
git clone https://github.com/mcassaniti/ftdi-uefi-serial.git
cd ftdi-uefi-serial

# Build for X64 (Default)
./build.sh X64

# Or build for ARM64 (AArch64)
./build.sh AARCH64

# Or build all supported architectures
./build.sh all
```

Output binaries are placed in `./bin/`:

* `bin/FtdiUsbSerialDxe-X64.efi`
* `bin/FtdiUsbSerialDxe-AARCH64.efi`

---

## 6. Deployment & Usage

### Option A: Automatic Loading via systemd-boot

Place the compiled driver on the target's EFI System Partition (ESP):

```bash
sudo cp bin/FtdiUsbSerialDxe-X64.efi /boot/efi/EFI/systemd/drivers/FtdiUsbSerialDxe.efi
```

`systemd-boot` automatically loads all drivers in `EFI/systemd/drivers/` before presenting the boot menu. Thanks to the auto-attach feature patch, the `systemd-boot` menu will immediately display and accept input over the serial console.

### Option B: Manual Loading via UEFI Shell

Copy `FtdiUsbSerialDxe.efi` to a USB drive or ESP, boot into the UEFI Shell, and run:

```efi
Shell> load fs0:\FtdiUsbSerialDxe.efi
```

### Option C: Linux Kernel Console Handover

Add the serial console parameters to your bootloader configuration (e.g. `/boot/loader/entries/*.conf` or `/etc/default/grub`). This can be combined with option A.

```text
console=tty0 console=ttyUSB0,115200n8
```

### Host Connection:

On your workstation, connect using your preferred serial terminal emulator:

```bash
# picocom
picocom -b 115200 /dev/ttyUSB0

# screen
screen /dev/ttyUSB0 115200
```

---

## 7. Repository Structure

```text
.
├── Dockerfile                   # Multi-arch EDK II container build environment
├── FtdiUsbSerial.dsc            # Standalone EDK II platform description
├── README.md                    # Project overview & documentation
├── WIRING-DIAGRAM.md            # Hardware schematics, truth table & BOM
├── build.sh                     # Automated Docker build wrapper script
├── entrypoint.sh                # Container entrypoint compilation script
├── bin/                         # Compiled EFI driver binaries (generated)
│   ├── FtdiUsbSerialDxe-X64.efi
│   ├── FtdiUsbSerialDxe-AARCH64.efi
│   └── FtdiUsbSerialDxe.efi
└── patches/                     # Upstream Tianocore patch series
    ├── 0001-Drivers-OptionRomPkg-Fix-zero-length-USB-control-req.patch
    ├── 0002-Drivers-OptionRomPkg-Fix-FlowControl-device-path-in-.patch
    ├── 0003-Drivers-OptionRomPkg-Increase-FTDI_TIMEOUT-for-virtu.patch
    └── 0004-Drivers-OptionRomPkg-Auto-attach-console-protocols-i.patch
```

---

## License

This project is licensed under the **BSD-2-Clause-Patent** license to maintain full compatibility with the [Tianocore EDK II Project](https://github.com/tianocore/edk2/blob/master/License.txt).
