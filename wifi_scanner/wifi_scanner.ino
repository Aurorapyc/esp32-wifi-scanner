/*

 * ============================================================
 *  ESP32 WiFi 扫描仪
 * ============================================================
 *  功能  : 扫描周围所有 2.4GHz WiFi，通过内置网页实时展示
 *          SSID、信号强度(RSSI)、信道、BSSID(MAC)、加密方式。
 *  硬件  : 标准 ESP32 开发板（Arduino 里选 "ESP32 Dev Module"）
 *          + 一根 USB 数据线，不需要任何接线。
 *  环境  : Arduino IDE，需先安装 esp32 开发板包：
 *          文件 → 首选项 → 附加开发板管理器网址，填入：
 *          https://espressif.github.io/arduino-esp32/package_esp32_index.json
 *          然后：工具 → 开发板管理器 → 搜索 esp32 → 安装。
 *  使用  :
 *          1. 上传本程序后，ESP32 会创建一个热点 "WiFi-Scanner"
 *          2. 手机 / 电脑连接该热点（密码 12345678）
 *          3. 浏览器打开 http://192.168.4.1
 * ============================================================
 */

#include <WiFi.h>
#include <WebServer.h>

// ======================= 配置区 =======================
// 热点名称与密码（密码至少 8 位；如果想开放热点，把密码留空 ""）
const char* AP_SSID = "WiFi-Scanner";
const char* AP_PASS = "12345678";

// 可选：填入你家路由器账号，让 ESP32 改连路由器、在局域网里访问
// （留空 = 使用上面的热点模式；填了 = 连接 STA_SSID 那个网络）
const char* STA_SSID = "711";
const char* STA_PASS = "Abc1234567890";

// 自动扫描间隔（毫秒）
const unsigned long SCAN_INTERVAL_MS = 4000;
// =======================================================

WebServer server(80);

#define MAX_NETWORKS 64

struct NetInfo {
  String   ssid;
  String   bssid;
  int32_t  rssi;
  uint8_t  channel;
  uint8_t  enc;
};

NetInfo networks[MAX_NETWORKS];
int networkCount = 0;
unsigned long lastScanStart = 0;
bool scanning = false;
unsigned long lastScanDoneMs = 0;

// ---------- 加密类型名称 ----------
const char* encName(uint8_t e) {
  switch (e) {
    case 0: return "开放";      // WIFI_AUTH_OPEN
    case 1: return "WEP";
    case 2: return "WPA";
    case 3: return "WPA2";
    case 4: return "WPA/WPA2";
    case 5: return "WPA2企业";
    case 6: return "WPA3";
    case 7: return "WPA2/WPA3";
    case 8: return "WAPI";
    default: return "未知";
  }
}

// ---------- 发起一次异步扫描（非阻塞） ----------
void startScan() {
  if (scanning) return;
  scanning = true;
  lastScanStart = millis();
  WiFi.scanNetworks(true);
}

// ---------- 每次 loop 检查扫描是否完成 ----------
void pollScan() {
  if (!scanning) return;

  // 安全保护：超过 12 秒还没完成就强制复位，避免卡死
  if (millis() - lastScanStart > 12000) {
    WiFi.scanDelete();
    scanning = false;
    return;
  }

  int n = WiFi.scanComplete();
  if (n == WIFI_SCAN_RUNNING) return;   // 还在扫描中
  if (n == WIFI_SCAN_FAILED) {          // 扫描失败
    WiFi.scanDelete();
    scanning = false;
    return;
  }

  // 扫描完成，保存结果
  networkCount = (n > MAX_NETWORKS) ? MAX_NETWORKS : n;
  for (int i = 0; i < networkCount; i++) {
    networks[i].ssid    = WiFi.SSID(i);
    networks[i].bssid   = WiFi.BSSIDstr(i);
    networks[i].rssi    = WiFi.RSSI(i);
    networks[i].channel = WiFi.channel(i);
    networks[i].enc     = (uint8_t)WiFi.encryptionType(i);
  }
  WiFi.scanDelete();
  scanning = false;
  lastScanDoneMs = millis();

  // 按信号强度从强到弱排序
  for (int i = 0; i < networkCount - 1; i++)
    for (int j = i + 1; j < networkCount; j++)
      if (networks[j].rssi > networks[i].rssi) {
        NetInfo t = networks[i];
        networks[i] = networks[j];
        networks[j] = t;
      }
}

// ---------- JSON 字符串转义（防止特殊字符破坏格式） ----------
String jsonEscape(const String& in) {
  String out;
  out.reserve(in.length() + 8);
  for (size_t i = 0; i < in.length(); i++) {
    unsigned char c = (unsigned char)in[i];
    switch (c) {
      case '"':  out += "\\\""; break;
      case '\\': out += "\\\\"; break;
      case '\n': out += "\\n";  break;
      case '\r': out += "\\r";  break;
      case '\t': out += "\\t";  break;
      default:
        if (c < 0x20) {
          char buf[8];
          snprintf(buf, sizeof(buf), "\\u%04X", (unsigned)c);
          out += buf;
        } else {
          out += (char)c;        // 原样保留 UTF-8 字节（中文 SSID）
        }
    }
  }
  return out;
}

// ============================================================
//  网页（HTML + CSS + JS，全部内联，不依赖外网资源）
// ============================================================
static const char PAGE[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ESP32 WiFi 扫描仪</title>
<style>
:root{
  color-scheme:dark;
  --bg:#0a0d13;
  --panel:#121722;
  --panel2:#0d1119;
  --line:#1f2837;
  --text:#e8ecf3;
  --muted:#7e8a9c;
  --accent:#5aa2ff;
  --green:#3dd68c;
  --yellow:#ffc94d;
  --orange:#ff9f45;
  --red:#ff6b6b;
  --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,"Courier New",monospace;
}
*{box-sizing:border-box;margin:0;padding:0}
html{-webkit-text-size-adjust:100%}
body{background:
  radial-gradient(1200px 500px at 70% -10%,#16233b 0%,transparent 60%),
  var(--bg);
  color:var(--text);
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"PingFang SC","Microsoft YaHei",sans-serif;
  min-height:100vh;padding:24px 16px 48px}
.wrap{max-width:920px;margin:0 auto}

header{display:flex;align-items:flex-end;justify-content:space-between;gap:16px;flex-wrap:wrap;margin-bottom:22px}
.brand{display:flex;align-items:center;gap:14px}
.radar{width:40px;height:40px;border-radius:50%;position:relative;
  border:1px solid var(--line);background:radial-gradient(circle,rgba(90,162,255,.18) 0%,transparent 70%);flex:0 0 auto}
.radar::before,.radar::after{content:"";position:absolute;border-radius:50%}
.radar::before{inset:8px;border:1px solid rgba(90,162,255,.5)}
.radar::after{inset:16px;background:var(--accent);box-shadow:0 0 10px var(--accent)}
.radar.live::after{animation:pulse 1.6s ease-in-out infinite}
@keyframes pulse{0%,100%{transform:scale(1);opacity:1}50%{transform:scale(.55);opacity:.5}}
h1{font-size:22px;font-weight:700;letter-spacing:.2px}
.sub{color:var(--muted);font-size:12px;margin-top:3px}
.status{display:flex;align-items:center;gap:8px;color:var(--muted);font-size:13px}
.status .dot{width:8px;height:8px;border-radius:50%;background:var(--green);box-shadow:0 0 8px var(--green)}
.status.scanning .dot{background:var(--yellow);box-shadow:0 0 8px var(--yellow);animation:pulse 1s ease-in-out infinite}
.status .mono{font-family:var(--mono);color:var(--text)}

.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:18px}
.card{background:var(--panel);border:1px solid var(--line);border-radius:12px;padding:14px 16px}
.card .k{font-size:12px;color:var(--muted)}
.card .v{font-family:var(--mono);font-size:24px;font-weight:700;margin-top:6px;font-variant-numeric:tabular-nums}
.card .v.accent{color:var(--accent)}
.card .v.green{color:var(--green)}

.panel{background:var(--panel);border:1px solid var(--line);border-radius:14px;overflow:hidden}
.toolbar{display:flex;align-items:center;gap:10px;padding:12px 14px;border-bottom:1px solid var(--line);flex-wrap:wrap}
.search{flex:1;min-width:180px;display:flex;align-items:center;gap:8px;background:var(--panel2);border:1px solid var(--line);border-radius:8px;padding:8px 12px}
.search input{background:none;border:none;outline:none;color:var(--text);font-size:14px;width:100%}
.search svg{flex:0 0 auto;opacity:.5}
.btn{background:var(--accent);color:#08131f;border:none;border-radius:8px;padding:9px 14px;font-size:13px;font-weight:600;cursor:pointer}
.btn:hover{filter:brightness(1.08)}
.btn:active{transform:translateY(1px)}
.toolbar .meta{color:var(--muted);font-size:12px;font-family:var(--mono)}

.tblwrap{overflow-x:auto}
table{width:100%;border-collapse:collapse;font-size:14px}
thead th{position:sticky;top:0;background:var(--panel2);color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.8px;text-align:left;padding:10px 14px;border-bottom:1px solid var(--line);font-weight:600;white-space:nowrap}
tbody td{padding:11px 14px;border-bottom:1px solid var(--line);vertical-align:middle;white-space:nowrap}
tbody tr:last-child td{border-bottom:none}
tbody tr:hover{background:rgba(255,255,255,.025)}
td.ssid{max-width:260px;overflow:hidden;text-overflow:ellipsis;font-weight:600}
td.ch{font-family:var(--mono);text-align:center;color:var(--muted)}
td.mono{font-family:var(--mono);color:var(--muted)}
td.rssi{color:var(--text);font-weight:600}
.sig{display:flex;align-items:center;gap:10px}
.bars{display:inline-flex;align-items:flex-end;gap:2px;height:16px}
.bars i{width:4px;border-radius:1px;background:var(--line)}
.bars i:nth-child(1){height:5px}
.bars i:nth-child(2){height:8px}
.bars i:nth-child(3){height:11px}
.bars i:nth-child(4){height:14px}
.bars i:nth-child(5){height:16px}
.strength{font-size:12px}
.empty{padding:40px;text-align:center;color:var(--muted)}
.empty .big{font-size:30px;margin-bottom:8px;opacity:.5}
footer{margin-top:20px;color:var(--muted);font-size:12px;text-align:center;line-height:1.7}
@media(max-width:640px){
  .cards{grid-template-columns:1fr}
  body{padding:16px 10px 40px}
  h1{font-size:19px}
}
@media (prefers-reduced-motion: reduce){
  .radar.live::after,.status.scanning .dot{animation:none}
}
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="brand">
      <div class="radar live"></div>
      <div>
        <h1>WiFi 扫描仪</h1>
        <div class="sub">ESP32 · 2.4 GHz 频谱探测器</div>
      </div>
    </div>
    <div class="status" id="status"><span class="dot"></span><span id="statusText">正在扫描…</span></div>
  </header>

  <div class="cards">
    <div class="card"><div class="k">检测到网络</div><div class="v accent" id="count">0</div></div>
    <div class="card"><div class="k">显示 / 总数</div><div class="v" id="shown">0 / 0</div></div>
    <div class="card"><div class="k">最后更新</div><div class="v green" id="time">--:--:--</div></div>
  </div>

  <div class="panel">
    <div class="toolbar">
      <div class="search">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg>
        <input id="filter" type="text" placeholder="搜索 SSID…" autocomplete="off">
      </div>
      <button class="btn" id="rescan">重新扫描</button>
      <span class="meta">每 4 秒自动刷新</span>
    </div>
    <div class="tblwrap">
      <table>
        <thead>
          <tr><th>信号</th><th>SSID</th><th>信道</th><th>BSSID</th><th>强度</th><th>加密</th></tr>
        </thead>
        <tbody id="rows"></tbody>
      </table>
    </div>
  </div>

  <footer>
    连接 ESP32 的 “WiFi-Scanner” 热点后访问本页。<br>
    扫描时 ESP32 会短暂切换信道，页面会自动刷新。
  </footer>
</div>

<script>
var REFRESH_MS = 4000;
var timer = null;

function signalLevel(rssi){
  if (rssi >= -55) return 5;
  if (rssi >= -62) return 4;
  if (rssi >= -70) return 3;
  if (rssi >= -78) return 2;
  if (rssi >= -85) return 1;
  return 0;
}
function levelColor(l){
  if (l >= 4) return '#3dd68c';
  if (l === 3) return '#ffc94d';
  if (l === 2) return '#ff9f45';
  return '#ff6b6b';
}
function strengthLabel(rssi){
  if (rssi >= -50) return '极强';
  if (rssi >= -60) return '强';
  if (rssi >= -70) return '一般';
  if (rssi >= -80) return '弱';
  return '很弱';
}

function render(nets){
  var tbody = document.getElementById('rows');
  tbody.innerHTML = '';
  var q = (document.getElementById('filter').value || '').trim().toLowerCase();
  var shown = 0;
  nets.forEach(function(n){
    var name = (n.ssid || '').trim();
    if (!name) name = '〈隐藏网络〉';
    if (q && name.toLowerCase().indexOf(q) === -1) return;
    shown++;

    var tr = document.createElement('tr');

    var tdSig = document.createElement('td');
    tdSig.className = 'sig';
    var lv = signalLevel(n.rssi);
    var color = levelColor(lv);
    var bars = document.createElement('span');
    bars.className = 'bars';
    for (var i = 0; i < 5; i++){
      var b = document.createElement('i');
      if (i < lv){ b.style.background = color; }
      bars.appendChild(b);
    }
    tdSig.appendChild(bars);
    var st = document.createElement('span');
    st.className = 'strength';
    st.style.color = color;
    st.textContent = strengthLabel(n.rssi);
    tdSig.appendChild(st);

    var tdName = document.createElement('td');
    tdName.className = 'ssid';
    tdName.textContent = name;

    var tdCh = document.createElement('td');
    tdCh.className = 'ch';
    tdCh.textContent = n.channel;

    var tdB = document.createElement('td');
    tdB.className = 'mono';
    tdB.textContent = n.bssid || '--';

    var tdR = document.createElement('td');
    tdR.className = 'mono rssi';
    tdR.textContent = n.rssi + ' dBm';

    var tdE = document.createElement('td');
    tdE.textContent = n.enc || '--';

    tr.appendChild(tdSig);
    tr.appendChild(tdName);
    tr.appendChild(tdCh);
    tr.appendChild(tdB);
    tr.appendChild(tdR);
    tr.appendChild(tdE);
    tbody.appendChild(tr);
  });

  document.getElementById('shown').textContent = shown + ' / ' + nets.length;

  if (!nets.length){
    var tr = document.createElement('tr');
    var td = document.createElement('td');
    td.colSpan = 6;
    td.className = 'empty';
    td.innerHTML = '未发现任何 WiFi 网络，等待下一次扫描…';
    tr.appendChild(td);
    tbody.appendChild(tr);
  }
}

function load(){
  fetch('/api/networks').then(function(r){ return r.json(); }).then(function(d){
    var list = d.networks || [];
    render(list);
    document.getElementById('count').textContent = d.count || 0;
    var st = document.getElementById('status');
    var txt = document.getElementById('statusText');
    if (d.scanning){
      st.className = 'status scanning';
      txt.textContent = '扫描中…';
    } else {
      st.className = 'status';
      txt.textContent = '信号正常';
    }
    var t = new Date();
    document.getElementById('time').textContent =
      ('0'+t.getHours()).slice(-2)+':'+('0'+t.getMinutes()).slice(-2)+':'+('0'+t.getSeconds()).slice(-2);
  }).catch(function(){
    document.getElementById('statusText').textContent = '连接中断，正在重试…';
  });
}

document.getElementById('filter').addEventListener('input', load);

document.getElementById('rescan').addEventListener('click', function(){
  fetch('/scan').catch(function(){});
  document.getElementById('statusText').textContent = '已请求扫描…';
});

function start(){
  load();
  if (timer) clearInterval(timer);
  timer = setInterval(load, REFRESH_MS);
}
start();
</script>
</body>
</html>
)rawliteral";

// ---------- HTTP: 首页 ----------
void handleRoot() {
  server.send(200, "text/html; charset=utf-8", PAGE);
}

// ---------- HTTP: 扫描结果 JSON ----------
void handleNetworks() {
  String json = "{\"count\":" + String(networkCount);
  json += ",\"scanning\":" + String(scanning ? 1 : 0);
  json += ",\"time\":" + String(lastScanDoneMs);
  json += ",\"networks\":[";
  for (int i = 0; i < networkCount; i++) {
    if (i) json += ',';
    json += "{\"ssid\":\"" + jsonEscape(networks[i].ssid) + "\"";
    json += ",\"bssid\":\"" + networks[i].bssid + "\"";
    json += ",\"rssi\":" + String(networks[i].rssi);
    json += ",\"channel\":" + String(networks[i].channel);
    json += ",\"enc\":\"" + String(encName(networks[i].enc)) + "\"}";
  }
  json += "]}";
  server.sendHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  server.send(200, "application/json", json);
}

// ---------- HTTP: 手动触发一次扫描 ----------
void handleScan() {
  startScan();
  server.send(200, "application/json", "{\"status\":\"scanning\"}");
}

// ============================================================
//  初始化
// ============================================================
void setup() {
  Serial.begin(115200);
  delay(300);
  Serial.println();
  Serial.println("ESP32 WiFi Scanner starting...");

  bool useSTA = (strlen(STA_SSID) > 0);
  if (useSTA) {
    WiFi.mode(WIFI_STA);
    WiFi.begin(STA_SSID, STA_PASS);
    unsigned long t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < 15000) {
      delay(400);
      Serial.print('.');
    }
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println();
      Serial.println("[!] 连接路由器失败，改用热点模式");
      useSTA = false;
    } else {
      Serial.println();
      Serial.print("[OK] 已连接路由器，浏览器访问 http://");
      Serial.println(WiFi.localIP());
    }
  }

  if (!useSTA) {
    WiFi.mode(WIFI_AP);
    if (strlen(AP_PASS) >= 8) {
      WiFi.softAP(AP_SSID, AP_PASS);
    } else {
      WiFi.softAP(AP_SSID);
    }
    Serial.print("[OK] 热点已创建: ");
    Serial.print(AP_SSID);
    Serial.println(" (密码: " + String(AP_PASS) + ")");
    Serial.print("[OK] 浏览器访问 http://");
    Serial.println(WiFi.softAPIP());
  }

  server.on("/", handleRoot);
  server.on("/api/networks", handleNetworks);
  server.on("/scan", handleScan);
  server.begin();
  Serial.println("[OK] HTTP 服务已启动");

  startScan();
}

void loop() {
  server.handleClient();
  pollScan();
  if (!scanning && millis() - lastScanStart >= SCAN_INTERVAL_MS) {
    startScan();
  }
}
