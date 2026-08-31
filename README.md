# ESP32 WiFi 扫描仪

基于标准 ESP32 开发板打造的 WiFi 扫描工具：扫描周围所有 2.4GHz 无线信号，通过 ESP32 自带的热点网页实时显示每个网络的 **SSID、信号强度(RSSI)、信道、BSSID(MAC)、加密方式**，并按信号强弱自动排序。

不需要任何额外接线，一根 USB 数据线即可运行。

---

## 功能

- 扫描周围所有 WiFi，自动按信号强度从强到弱排序
- 网页实时展示（每 4 秒自动刷新，也可手动「重新扫描」）
- 每条信号带可视化强度条 + 颜色分级（极强/强/一般/弱/很弱）
- 显示 SSID、信道、BSSID(MAC)、RSSI(dBm)、加密类型
- 支持按 SSID 关键字搜索过滤
- 隐藏网络（不广播 SSID）也能识别，显示为「〈隐藏网络〉」

## 硬件准备

| 物品 | 说明 |
|------|------|
| ESP32 开发板 | 标准版即可（ESP32 Dev Module），带 CP2102 串口芯片 |
| USB 数据线 | 必须是**数据线**（能传数据，不是只能充电的那种） |
| 电脑 | Windows / macOS / Linux 均可 |

> 你的板子串口芯片是 CP2102。如果插上电脑后设备管理器里**看不到 COM 口**，请先安装驱动：
> 打开本目录下的 `.drivers` 文件夹，双击运行 `install_cp210x.ps1`（需要管理员权限），
> 或安装其中的 `CP210x_Universal_Windows_Driver.zip`。

## 软件环境

1. 安装 **Arduino IDE**（官网 https://www.arduino.cc/en/software，2.x 版本即可）
2. 给 Arduino IDE 安装 ESP32 支持：
   - 打开 `文件 → 首选项`
   - 在「附加开发板管理器网址」中填入：
     ```
     https://espressif.github.io/arduino-esp32/package_esp32_index.json
     ```
   - 点击「确定」
   - 打开 `工具 → 开发板 → 开发板管理器`
   - 搜索 `esp32`，选择 **esp32 by Espressif Systems**，点击「安装」（下载约 200MB，稍等片刻）

## 烧录步骤

1. 用 USB 数据线把 ESP32 连到电脑
2. 打开 Arduino IDE：`文件 → 打开`，选择本目录下的
   `wifi_scanner\wifi_scanner.ino`
3. 选择开发板：`工具 → 开发板 → ESP32 Arduino → ESP32 Dev Module`
4. 选择端口：`工具 → 端口`，选择对应的 COM 口
   （Windows 上通常叫 `COM3` 或类似名字；如果看不到，见下方常见问题）
5. 点右上角「→」（上传）。首次编译会比较久，之后会提示 `Connecting...` 并完成上传
6. 打开 `工具 → 串口监视器`，波特率选 `115200`，可以看到 ESP32 打印出热点地址

## 使用方法

1. 烧录完成后，ESP32 会自动创建一个 WiFi 热点：**`WiFi-Scanner`**，密码 **`12345678`**
2. 用手机或电脑连接这个热点
3. 浏览器打开 **`http://192.168.4.1`**（如果打不开，也可以在手机热点设置里查看 ESP32 分配的 IP，通常是 192.168.4.1 或 192.168.4.2）
4. 即可看到周围所有 WiFi 信号，页面每 4 秒自动刷新一次

> 提示：因为网页就运行在 ESP32 的热点里，扫描时 ESP32 需要短暂切换信道，页面会自动重连刷新，属正常现象。

## 修改热点名称 / 密码

打开 `wifi_scanner.ino`，找到文件开头的「配置区」：

```cpp
const char* AP_SSID = "WiFi-Scanner";   // 热点名称
const char* AP_PASS = "12345678";       // 热点密码（至少 8 位，留空=开放热点）
```

改完后重新上传即可。

## 想改成连接家里的路由器？（可选）

如果你希望 ESP32 连入家里路由器、在同一局域网内访问扫描页面（比如电脑和 ESP32 连同一个 WiFi），
把配置区的 `STA_SSID` 和 `STA_PASS` 填上：

```cpp
const char* STA_SSID = "你家WiFi名称";
const char* STA_PASS = "你家WiFi密码";
```

这样 ESP32 会去连接路由器，串口监视器会打印出它的局域网 IP（例如 `192.168.1.100`），用浏览器访问该 IP 即可。留空则保持热点模式。

## 项目结构

```
esp32/
├── wifi_scanner/
│   └── wifi_scanner.ino     # Arduino 固件（全部代码都在这里）
└── README.md                # 本说明
```

代码依赖：仅使用 ESP32 官方核心自带的 `WiFi.h` 和 `WebServer.h`，**无需安装任何第三方库**。

## 常见问题

**Q：上传时一直卡在 `Connecting...` 或报 `Failed to connect`**
A：按住板子上的 **BOOT/EN** 按钮不松手，点上传，出现 `Connecting...` 时松手；或者换一根 USB 数据线。

**Q：设备管理器里没有 COM 口**
A：驱动没装好。运行 `.drivers` 文件夹里的 `install_cp210x.ps1`（右键 → 用 PowerShell 运行，允许管理员权限），或者安装 `CP210x_Universal_Windows_Driver.zip`。装好后重新插拔 USB 线。

**Q：打开 192.168.4.1 打不开**
A：确认手机/电脑确实连上了 `WiFi-Scanner` 热点；部分手机连热点时会提示「无互联网连接」，选择「保持连接」即可。也可以查看手机热点详情里 ESP32 分配的 IP，换那个 IP 访问。

**Q：网页能打开但列表是空的**
A：扫描需要几秒，等页面自动刷新两次；如果周围真的没有 2.4GHz 网络（比如路由器开了 5GHz-only）就扫不到。ESP32 只支持 2.4GHz。

**Q：扫描时手机显示热点掉线/无网络**
A：这是正常的。ESP32 扫描时会短暂切换信道，导致热点瞬间不可用，页面会自动重连刷新。

## 相关文档

- [技术文档](wifi-scanner-technical-document.md)
- [版本记录](CHANGELOG.md)
