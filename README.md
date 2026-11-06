<div align="center">

# 🎧 AirSwitch

**One-key Bluetooth audio switcher & floating battery HUD for macOS.**  
Toggle your AirPods, Sony, Bose, or Beats between your Mac and phone with a single shortcut — or automatically when you open and close your laptop lid.

[![Latest Release](https://img.shields.io/github/v/release/MatthieuD134/AirSwitch?label=Release&color=brightgreen)](https://github.com/MatthieuD134/AirSwitch/releases/latest)
[![CI](https://github.com/MatthieuD134/AirSwitch/actions/workflows/ci.yml/badge.svg)](https://github.com/MatthieuD134/AirSwitch/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/macOS-14.0%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

```
┌────────────────────────────────────────────────────────┐
│   🎧  AirPods Pro · Connected · L 90% · R 85% 🔋       │
└────────────────────────────────────────────────────────┘
```

[**Download `.dmg`**](https://github.com/MatthieuD134/AirSwitch/releases/latest/download/AirSwitch.dmg) · [**Releases**](https://github.com/MatthieuD134/AirSwitch/releases) · [**Report an Issue**](https://github.com/MatthieuD134/AirSwitch/issues)

</div>

---

## Install

### One-Line Install (Recommended)

Installs `AirSwitch.app` into `/Applications` and launches it immediately — no Xcode or `git` required:

```bash
curl -fsSL https://raw.githubusercontent.com/MatthieuD134/AirSwitch/main/install.sh | bash
```

### Direct Download (`.dmg`)

1. Download [**AirSwitch.dmg**](https://github.com/MatthieuD134/AirSwitch/releases/latest/download/AirSwitch.dmg) and drag **AirSwitch** to **Applications**.
2. *(First launch only)* Because the app is ad-hoc signed rather than Apple-notarized, if macOS Gatekeeper prompts you, **Right-click → Open** or run:
   ```bash
   xattr -cr /Applications/AirSwitch.app
   ```

---

## Why AirSwitch?

Apple's built-in AirPods auto-switching **only works if your Mac and iPhone are signed into the same iCloud account** — which fails on work laptops and non-Apple headphones. Switching manually through Control Center takes 3–4 clicks every time.

| Problem | With AirSwitch |
| :--- | :--- |
| Work Mac + personal iPhone don't share iCloud | Hit **`⌃⌥A`** to grab or release your headphones in under a second |
| Opening your laptop in the morning | Automatically connects your headphones on wake |
| Closing your laptop to commute | Automatically disconnects so your phone takes over immediately |
| Checking earbud & case battery | Live percentage in the menu bar (`85%`) and floating notch HUD |

---

## Highlights

- **⚡ Instant Global Hotkey (`⌃⌥A`)** — Registered via Carbon `RegisterEventHotKey`. Works system-wide with **zero Accessibility permissions** required.
- **💻 Lid Open / Close Automation** — Auto-connects on wake and auto-disconnects on sleep.
- **🔋 Dynamic Capsule HUD** — Translucent pill beneath the notch displays connection state and Left / Right / Case battery levels.
- **🎧 Universal Bluetooth Support** — Works with AirPods, AirPods Pro/Max, Sony WH-1000XM4/XM5, Bose QuietComfort, Beats, and Bluetooth speakers.
- **🪶 Tiny & Native** — Pure Swift (`AppKit`, `IOBluetooth`, `IOKit`, `ServiceManagement`) with **zero external dependencies**.

---

## Usage

### Menu Bar & Shortcuts

| Action | Trigger |
| :--- | :--- |
| Toggle connection to primary device | **`⌃⌥A`** (`Control + Option + A`) anywhere on macOS |
| Quick toggle from menu bar | **Left-click** the menu bar icon |
| Open settings & device picker | **Right-click** (or `Control`-click) the menu bar icon |

From the right-click menu you can:
- Pick your **Target Audio Device** from paired Bluetooth audio devices
- View detailed battery status (`L / R / Case`)
- Toggle **Auto-connect on Wake** and **Auto-disconnect on Sleep**
- Toggle **Show Floating Battery HUD** and **HUD Animations**
- Enable **Launch at Login**

### CLI & Raycast / Alfred Scripting

The binary inside the app bundle (or installed via `make install`) doubles as a scriptable CLI:

```bash
airswitch --list                  # List paired audio devices with MAC address and battery
airswitch --select "AirPods"      # Set primary target device (by name or MAC address)
airswitch --toggle                # Toggle connection of primary target device
airswitch --connect "AirPods"     # Connect a specific device
airswitch --disconnect "AirPods"  # Disconnect a specific device
airswitch --version               # Print version
```

> **Tip:** Point a Raycast Script Command or Alfred Workflow at `/Applications/AirSwitch.app/Contents/MacOS/airswitch --toggle`.

---

## Build from Source

Requires macOS 14.0+ and Swift 5.9+ (`xcode-select --install`):

```bash
git clone https://github.com/MatthieuD134/AirSwitch.git
cd AirSwitch
make install-app
open /Applications/AirSwitch.app
```

| Makefile Target | Description |
| :--- | :--- |
| `make app` | Build standalone `build/AirSwitch.app` bundle |
| `make install-app` | Build and install `AirSwitch.app` into `/Applications` |
| `make dmg` | Package `build/AirSwitch.dmg` with `/Applications` shortcut |
| `make install` | Install CLI binary to `~/.local/bin/airswitch` |
| `make test` | Run unit test suite |
| `make release` | Bump version (`VERSION=x.y.z` optional), tag, and push GitHub Release |
| `make uninstall` | Stop AirSwitch and remove `/Applications/AirSwitch.app` & CLI binary |

---

## Uninstall

Quit AirSwitch from the menu bar (or stop it) and remove the app:

```bash
pkill -f AirSwitch.app || true
rm -rf /Applications/AirSwitch.app
```

---

## License

[MIT](LICENSE) © Matthieu Daulhiac
