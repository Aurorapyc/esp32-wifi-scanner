# ESP32 WiFi Scanner

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-ESP32-blue">
  <img alt="Language" src="https://img.shields.io/badge/Language-C%2B%2B-orange">
  <img alt="Framework" src="https://img.shields.io/badge/Framework-Arduino-00979D">
  <img alt="License" src="https://img.shields.io/badge/License-Not%20Selected-lightgrey">
  <br>
  Scan nearby 2.4 GHz Wi-Fi networks and view signal strength, channel, and security in your browser — no extra hardware required.
</p>

[简体中文](README_zh-CN.md) · [Technical Document](wifi-scanner-technical-document.md)

## Table of Contents

- [Features](#features)
- [Hardware Requirements](#hardware-requirements)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Configuration](#configuration)
- [Web Interface](#web-interface)
- [API](#api)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- Scans all nearby 2.4 GHz Wi-Fi networks and sorts them by signal strength.
- Built-in web page auto-refreshes every 4 seconds.
- Shows SSID, channel, BSSID, RSSI (signal strength), and encryption type for each network.
- Visual signal bars with five-level color coding: Excellent, Good, Fair, Weak, and Very Weak.
- Detects hidden networks that do not broadcast their SSID.
- Search filter by SSID and a manual rescan button.
- Dual mode: create your own hotspot (AP) or connect to your home router (STA).
- No third-party libraries, only the official ESP32 core.

## Hardware Requirements

| Item | Requirement |
| --- | --- |
| ESP32 board | Standard ESP32 (for example DevKitC, WROOM-32), CP2102 USB-UART chip |
| USB cable | Must support data transfer |

No wiring is required. If the board is not detected by the computer, install the CP210x driver first.

## Getting Started

### Software Setup

1. Install [Arduino IDE](https://www.arduino.cc/en/software) 2.x.
2. Add the ESP32 board package URL:
   - Open `File → Preferences`.
   - In **Additional boards manager URLs**, add:
   ```
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```
3. Open Boards Manager (`Tools → Board → Boards Manager`), search for `esp32`, and install `esp32 by Espressif Systems`.

> The board package is downloaded from GitHub. In restricted networks, the download may fail. Configure a proxy or use a GitHub mirror if needed.

### Flashing

1. Open `wifi_scanner/wifi_scanner.ino` in Arduino IDE.
2. Select the board: `Tools → Board → ESP32 Arduino → ESP32 Dev Module`.
3. Select the port: `Tools → Port`, choose the correct COM port.
4. Click **Upload** and wait for the build and upload to finish.

If the upload hangs at `Connecting...`, hold the BOOT button, click Upload, and release the button when upload starts.

## Usage

The firmware supports two modes. Open the Serial Monitor (baud rate 115200) to see which mode is active and which address to visit.

### AP Mode (default)

Leave `STA_SSID` empty. The ESP32 creates a hotspot:

- SSID: `WiFi-Scanner`
- Password: `12345678`
- URL: `http://192.168.4.1`

Connect a phone or computer to the hotspot and open the URL in a browser.

### STA Mode (connect to your router)

Fill in `STA_SSID` and `STA_PASS` at the top of `wifi_scanner/wifi_scanner.ino`. The ESP32 joins your router and prints its local IP in the Serial Monitor. You can also find it in the router's DHCP client list.

### Connection Fallback

If the router connection fails within 15 seconds, the firmware automatically falls back to AP mode. Note that the web server is not available during the first 15 seconds after boot.

## Configuration

Edit the configuration section at the top of `wifi_scanner/wifi_scanner.ino`.

| Setting | Default | Description |
| --- | --- | --- |
| `AP_SSID` | `WiFi-Scanner` | Hotspot name |
| `AP_PASS` | `12345678` | Hotspot password, at least 8 characters, empty means open hotspot |
| `STA_SSID` | empty | Your router name, leave empty for AP mode |
| `STA_PASS` | empty | Your router password |
| `SCAN_INTERVAL_MS` | `4000` | Scan interval in milliseconds |

## Web Interface

- The top cards show the number of networks, the displayed count, and the last update time.
- The table is sorted by signal strength and shows signal, SSID, channel, BSSID, RSSI, and encryption.
- The search box filters by SSID, and the Rescan button triggers a manual scan.
- The page auto-refreshes every 4 seconds.

### Signal Strength Levels

| Level | RSSI Range (dBm) |
| --- | --- |
| Excellent | >= -50 |
| Good | -60 to -50 |
| Fair | -70 to -60 |
| Weak | -80 to -70 |
| Very Weak | < -80 |

## API

The firmware embeds a small HTTP server:

| Endpoint | Description |
| --- | --- |
| `/` | Web page |
| `/api/networks` | Latest scan results, JSON format |
| `/scan` | Trigger a manual scan |

Example response:

```json
{
  "count": 12,
  "scanning": 0,
  "networks": [
    {
      "ssid": "MyWiFi",
      "bssid": "AA:BB:CC:DD:EE:FF",
      "rssi": -45,
      "channel": 6,
      "enc": "WPA2"
    }
  ]
}
```

## Project Structure

```
esp32/
├── wifi_scanner/
│   └── wifi_scanner.ino               # Firmware, all code in one file
├── README.md                          # This file
├── README_zh-CN.md                    # Chinese documentation
├── wifi-scanner-technical-document.md # Technical document
├── CHANGELOG.md                       # Version history
└── .gitignore
```

## Troubleshooting

**Cannot detect the COM port.** Install the CP210x driver, then re-plug the USB cable.

**Upload hangs at Connecting...** Hold the BOOT button while uploading, or try another USB cable.

**Cannot open the web page.** Make sure the device is connected to the correct hotspot or network and the IP is correct. Some phones show a "no internet connection" prompt when joining a hotspot, choose to stay connected.

**The list is empty.** Wait for two refresh cycles. If there are no 2.4 GHz networks nearby, the result is empty. The ESP32 does not support 5 GHz.

**Connected to the router but cannot find the IP.** Check the Serial Monitor. If it shows a connection failure, visit `http://192.168.4.1` instead.

## License

This project currently does not include an explicit license. All rights reserved. Contact the author for permission, or choose an open-source license.
