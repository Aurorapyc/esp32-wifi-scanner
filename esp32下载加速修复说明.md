# 解决「安装 esp32 开发板包失败 / 下载超时」问题

## 问题原因

安装 esp32 板包时，Arduino IDE 需要从 **GitHub** 下载好几个大工具链
（编译工具链、烧录工具、OpenOCD 等，一共好几个 GB）。

你所在的网络环境**直连 GitHub 经常超时**，所以下载失败，报错类似：

```
Failed to install platform: 'esp32:esp32:3.3.11'.
Error: 13 INTERNAL: Download failed: performing HEAD request:
Head "https://github.com/espressif/crosstool-NG/releases/download/..."
read tcp ... -> 20.205.243.166:443: A connection attempt failed...
```

（`20.205.243.166` 就是 GitHub 的服务器 IP。）

**这不是代码问题，也不是板子问题，纯粹是网络问题。**

---

## 方案一（推荐）：用加速镜像下载（不需要 VPN）

我们准备了一个一键脚本，把 Arduino 索引里所有 `github.com` 的下载地址
统一改走**国内可用的 GitHub 加速镜像**，然后重新安装即可。

### 操作步骤

1. **关闭 Arduino IDE**（必须完全关闭）
2. 打开本目录（`G:\Claude\esp32`），**双击 `run_fix.bat`**
   - 如果双击没反应，可以右键 `fix_esp32_download.ps1` → 「使用 PowerShell 运行」
3. 脚本会自动：
   - 找到 Arduino 的 esp32 索引文件并**先备份**
   - 测试几个可用的 GitHub 镜像，选一个能连上的
   - 把索引里的下载地址改成走镜像
4. 看到 `Done!` 后，按回车退出
5. **重新打开 Arduino IDE** → 开发板管理器 → 重新安装 **esp32 by Espressif Systems**
   - 工具 → 开发板 → 开发板管理器 → 搜索 `esp32` → 点安装
6. 这次下载会走镜像加速，不会再超时

### 如果还是失败

- 网络波动：直接**再点一次安装**，或稍等几分钟再试
- 镜像不稳定：**再运行一次 `run_fix.bat`**，它会换一个镜像重新改
- 想手动换镜像：用记事本打开 Arduino15 目录下的
  `package_esp32_index.json`，把里面的镜像域名
  （如 `gh-proxy.com`）换成下面任一个再保存：
  - `ghfast.top`
  - `ghproxy.net`
  - `ghproxy.homeboyc.cn`
  - `github.akams.cn`
- 想恢复原样：脚本备份的文件在 Arduino15 目录下，文件名类似
  `package_esp32_index.json.bak_20260831_101530`，
  把它复制回去覆盖原文件即可

---

## 方案二：如果你有 VPN / 代理

在 Arduino IDE 里配置代理最省事：

1. `文件 → 首选项 → 网络`（Network）
2. 勾选「手动配置代理」，填上你的代理地址和端口
3. 确定后重新安装 esp32

---

## 方案三：实在不行，试试反复点安装

GitHub 偶尔是"抽风"而非完全断连。有些时候多试几次、换个时间段
（比如凌晨）就能成功。但你的报错是稳定超时，所以**优先用方案一**。

---

## 验证安装是否成功

装完后，在开发板管理器里应该能看到 `esp32 by Espressif Systems` 显示已安装。
然后在 `工具 → 开发板 → ESP32 Arduino` 里能看到 **ESP32 Dev Module** 等板型，
选择它、选对 COM 口，就能编译烧录我们的 WiFi 扫描仪了。
