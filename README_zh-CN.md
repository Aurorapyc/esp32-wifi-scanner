# ESP32 WiFi 扫描仪

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/Platform-ESP32-blue">
  <img alt="Language" src="https://img.shields.io/badge/Language-C%2B%2B-orange">
  <img alt="Framework" src="https://img.shields.io/badge/Framework-Arduino-00979D">
  <img alt="License" src="https://img.shields.io/badge/License-Not%20Selected-lightgrey">
  <br>
  扫描周围 2.4 GHz 的 Wi-Fi 网络，在浏览器中查看信号强度、信道与加密方式，无需额外接线。
</p>

[English](README.md) · [技术文档](wifi-scanner-technical-document.md)

## 目录

- [功能](#功能)
- [硬件要求](#硬件要求)
- [快速上手](#快速上手)
- [使用方法](#使用方法)
- [配置](#配置)
- [网页界面](#网页界面)
- [接口](#接口)
- [项目结构](#项目结构)
- [常见问题](#常见问题)
- [许可证](#许可证)

## 功能

- 扫描周围所有 2.4 GHz 的 Wi-Fi 网络，并按信号强度从强到弱排序。
- 内置网页每 4 秒自动刷新。
- 每个网络展示 SSID、信道、BSSID、RSSI（信号强度）和加密类型。
- 可视化信号强度条，带五级颜色分级：极强、强、一般、弱、很弱。
- 可以识别不广播 SSID 的隐藏网络。
- 支持按 SSID 搜索过滤，并提供手动重新扫描按钮。
- 双模式：创建自己的热点（AP），或者连接家里的路由器（STA）。
- 无第三方库依赖，仅使用 ESP32 官方核心。

## 硬件要求

| 硬件 | 要求 |
| --- | --- |
| ESP32 开发板 | 标准版即可（例如 DevKitC、WROOM-32），串口芯片为 CP2102 |
| USB 数据线 | 必须支持数据传输 |

本项目不需要任何接线。如果电脑无法识别开发板，请先安装 CP210x 驱动。

## 快速上手

### 软件环境

1. 安装 [Arduino IDE](https://www.arduino.cc/en/software) 2.x。
2. 添加 ESP32 开发板包地址：
   - 打开 `文件 → 首选项`。
   - 在「附加开发板管理器网址」中填入：
   ```
   https://espressif.github.io/arduino-esp32/package_esp32_index.json
   ```
3. 打开开发板管理器（`工具 → 开发板 → 开发板管理器`），搜索 `esp32`，安装 `esp32 by Espressif Systems`。

> 开发板包需要从 GitHub 下载。在网络受限的环境中下载可能失败，需要配置代理或使用 GitHub 镜像。

### 烧录

1. 在 Arduino IDE 中打开 `wifi_scanner/wifi_scanner.ino`。
2. 选择开发板：`工具 → 开发板 → ESP32 Arduino → ESP32 Dev Module`。
3. 选择端口：`工具 → 端口`，选择对应的 COM 口。
4. 点击「上传」，等待编译和烧录完成。

如果上传卡在 `Connecting...`，按住开发板上的 BOOT 按钮，点击上传，出现提示时松开。

## 使用方法

固件支持两种模式。打开串口监视器（波特率 115200），可以查看当前模式和需要访问的地址。

### 热点模式（默认）

保持 `STA_SSID` 为空。ESP32 会创建一个热点：

- 热点名称：`WiFi-Scanner`
- 密码：`12345678`
- 地址：`http://192.168.4.1`

用手机或电脑连接该热点，在浏览器中打开地址即可。

### 路由器模式（连接家里的路由器）

在 `wifi_scanner/wifi_scanner.ino` 文件顶部填写 `STA_SSID` 和 `STA_PASS`。ESP32 会连接你的路由器，并在串口监视器中打印局域网地址。也可以在路由器的 DHCP 客户端列表中查找。

### 连接失败时的回退

如果 15 秒内连接路由器失败，固件会自动回退到热点模式。注意，开机后的 15 秒内网页服务器尚未启动。

## 配置

编辑 `wifi_scanner/wifi_scanner.ino` 文件顶部的配置区。

| 配置项 | 默认值 | 说明 |
| --- | --- | --- |
| `AP_SSID` | `WiFi-Scanner` | 热点名称 |
| `AP_PASS` | `12345678` | 热点密码，至少 8 位，留空表示开放热点 |
| `STA_SSID` | 空 | 路由器名称，留空使用热点模式 |
| `STA_PASS` | 空 | 路由器密码 |
| `SCAN_INTERVAL_MS` | `4000` | 扫描间隔，单位毫秒 |

## 网页界面

- 顶部卡片显示网络数量、显示数量和最后更新时间。
- 表格按信号强度排序，展示信号、SSID、信道、BSSID、强度和加密方式。
- 搜索框可以按 SSID 过滤，「重新扫描」按钮可以手动触发扫描。
- 页面每 4 秒自动刷新。

### 信号强度分级

| 等级 | RSSI 范围（dBm） |
| --- | --- |
| 极强 | 大于等于 -50 |
| 强 | -60 至 -50 |
| 一般 | -70 至 -60 |
| 弱 | -80 至 -70 |
| 很弱 | 小于 -80 |

## 接口

固件内置一个 HTTP 服务器：

| 路径 | 说明 |
| --- | --- |
| `/` | 扫描页面 |
| `/api/networks` | 最新扫描结果，JSON 格式 |
| `/scan` | 手动触发一次扫描 |

返回示例：

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

## 项目结构

```
esp32/
├── wifi_scanner/
│   └── wifi_scanner.ino               # 固件，全部代码在一个文件
├── README.md                          # 英文文档
├── README_zh-CN.md                    # 本文档
├── wifi-scanner-technical-document.md # 技术文档
├── CHANGELOG.md                       # 版本记录
└── .gitignore
```

## 常见问题

**电脑无法识别 COM 口。** 安装 CP210x 驱动，然后重新插拔 USB 线。

**上传卡在 Connecting...。** 上传时按住 BOOT 按钮，或者换一根 USB 数据线。

**页面无法打开。** 确认设备连接了正确的热点或网络，并且 IP 正确。部分手机连接热点时会提示「无互联网连接」，选择保持连接即可。

**列表为空。** 等待页面自动刷新两次。如果周围没有 2.4 GHz 网络，结果为空。ESP32 不支持 5 GHz 频段。

**连接了路由器但找不到 IP。** 查看串口监视器。如果显示连接失败，请访问 `http://192.168.4.1`。

## 许可证

本项目目前没有明确的许可证。保留所有权利。如需使用请联系作者，或选择一个开源许可证。
