#!/bin/bash
# VPN Keeper - 自动获取订阅、优选节点、重启代理
WORK_DIR="/Users/lopez/.hermes/vpn-keeper"
SUB_DIR="$WORK_DIR/subs"
LOG_DIR="$WORK_DIR/logs"
XRAY_BIN="/Applications/v2rayU.app/Contents/Resources/v2ray-core/v2ray"
CONFIG_FILE="$WORK_DIR/config/xray.json"
PID_FILE="$WORK_DIR/config/xray.pid"

mkdir -p "$SUB_DIR" "$LOG_DIR" "$WORK_DIR/config"
LOG="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }

log "获取 clashnode.top 最新订阅..."

# 关键修复：取消代理环境变量，确保直连国内网站
unset ALL_PROXY HTTPS_PROXY HTTP_PROXY all_proxy https_proxy http_proxy

# 尝试今天的订阅
TODAY=$(date +%Y%m%d)
YEAR=$(date +%Y)
MONTH=$(date +%m)
V2RAY_URL="https://node.clashnode.top/uploads/${YEAR}/${MONTH}/0-${TODAY}.txt"

log "订阅: $V2RAY_URL"
curl -sL --connect-timeout 10 "$V2RAY_URL" -o "$SUB_DIR/latest.txt" 2>/dev/null

if [ ! -s "$SUB_DIR/latest.txt" ]; then
    # 尝试昨天的
    YESTERDAY=$(date -v-1d +%Y%m%d)
    V2RAY_URL="https://node.clashnode.top/uploads/${YEAR}/${MONTH}/0-${YESTERDAY}.txt"
    curl -sL --connect-timeout 10 "$V2RAY_URL" -o "$SUB_DIR/latest.txt" 2>/dev/null
fi

if [ ! -s "$SUB_DIR/latest.txt" ]; then
    log "❌ 订阅下载失败，使用上次配置"
    exit 0
fi

log "下载完成，开始解析节点..."

XRAY_ASSET="/Applications/v2rayU.app/Contents/Resources/v2ray-core"

python3 << 'PYEOF' > "$CONFIG_FILE"
import base64, json, re, socket, time, sys
from concurrent.futures import ThreadPoolExecutor

def decode_vmess(url):
    try:
        b64 = url[8:].strip()
        padding = 4 - len(b64) % 4
        if padding != 4: b64 += '=' * padding
        return json.loads(base64.b64decode(b64))
    except: return None

def parse_links(filepath):
    nodes = []
    with open(filepath) as f:
        for line in f:
            line = line.strip()
            if line.startswith('vmess://'):
                d = decode_vmess(line)
                if d and d.get('add') and d.get('port'):
                    nodes.append({'proto': 'vmess', 'server': d['add'], 'port': str(d['port']), 'raw': line, 'name': d.get('ps','vmess')})
            elif line.startswith('vless://'):
                m = re.match(r'vless://([^@]+)@([^:]+):(\d+)', line)
                if m:
                    nodes.append({'proto': 'vless', 'server': m.group(2), 'port': m.group(3), 'raw': line, 'name': 'vless'})
    return nodes

def tcp_test(server, port, timeout=2):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        start = time.time()
        s.connect((server, int(port)))
        s.close()
        return round((time.time()-start)*1000, 1)
    except: return None

nodes = parse_links('/Users/lopez/.hermes/vpn-keeper/subs/latest.txt')
seen = set()
unique = []
for n in nodes:
    key = f"{n['server']}:{n['port']}"
    if key not in seen:
        seen.add(key)
        unique.append(n)

valid = []
with ThreadPoolExecutor(max_workers=30) as exe:
    futs = {exe.submit(tcp_test, n['server'], n['port']): n for n in unique[:80]}
    for f in futs:
        n = futs[f]
        lat = f.result()
        if lat and lat < 1500:
            n['latency'] = lat
            valid.append(n)

valid.sort(key=lambda x: x['latency'])
if not valid:
    print(json.dumps({"error": "no_valid_nodes"}))
    sys.exit(0)

best = valid[0]

# 1. 生成代理 Outbound
proxy_ob = {"tag": "proxy", "protocol": best['proto']}
if best['proto'] == 'vmess':
    d = decode_vmess(best['raw'])
    proxy_ob['settings'] = {"vnext": [{"address": d['add'], "port": int(d['port']), "users": [{"id": d['id'], "alterId": int(d.get('aid',0)), "security": d.get('scy','auto')}]}]}
    stream = {"network": d.get('net','tcp')}
    if d.get('tls') == 'tls':
        stream['security'] = 'tls'
        stream['tlsSettings'] = {"serverName": d.get('sni', d['add']), "allowInsecure": True}
    if d.get('net') == 'ws':
        stream['wsSettings'] = {"path": d.get('path','/'), "headers": {"Host": d.get('host','')}}
    proxy_ob['streamSettings'] = stream
elif best['proto'] == 'vless':
    m = re.match(r'vless://([^@]+)@([^:]+):(\d+)\?(.*)', best['raw'])
    if m:
        params = dict(q.split('=') for q in m.group(4).split('&') if '=' in q)
        proxy_ob['settings'] = {"vnext": [{"address": m.group(2), "port": int(m.group(3)), "users": [{"id": m.group(1), "encryption": "none", "flow": params.get('flow','')}]}]}
        stream = {"network": params.get('type','tcp')}
        if params.get('security') == 'tls':
            stream['security'] = 'tls'
            stream['tlsSettings'] = {"serverName": params.get('sni',''), "allowInsecure": True}
        if params.get('type') == 'ws':
            stream['wsSettings'] = {"path": params.get('path','/'), "headers": {"Host": params.get('host','')}}
        proxy_ob['streamSettings'] = stream

# 2. 组装完整配置（包含 Direct 路由规则）
config = {
    "log": {"loglevel": "warning"},
    "inbounds": [{"port": 1080, "listen": "127.0.0.1", "protocol": "socks", "settings": {"udp": True}}],
    "outbounds": [
        proxy_ob,
        {"tag": "direct", "protocol": "freedom", "settings": {}},
        {"tag": "block", "protocol": "blackhole", "settings": {}}
    ],
    "routing": {
        "rules": [
            # 国内域名直连
            {"type": "field", "domain": ["geosite:cn"], "outboundTag": "direct"},
            # 国内 IP 直连
            {"type": "field", "ip": ["geoip:cn"], "outboundTag": "direct"},
            # 其余所有流量走代理
            {"type": "field", "domain": ["regexp:.*"], "outboundTag": "proxy"}
        ]
    }
}

print(json.dumps(config, indent=2))
PYEOF

if [ ! -s "$CONFIG_FILE" ] || grep -q "no_valid_nodes" "$CONFIG_FILE"; then
    log "❌ 无有效节点，保持当前代理运行"
    exit 0
fi
log "✅ 配置已生成 (最快节点: $(grep -o '"tag": "[^"]*"' "$CONFIG_FILE" | head -1))"

# 重启 Xray (注意设置 ASSET 路径以加载 geo 数据)
log "重启 Xray..."
if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    sleep 1
fi

export XRAY_LOCATION_ASSET="$XRAY_ASSET"
nohup "$XRAY_BIN" -config "$CONFIG_FILE" > "$LOG_DIR/xray_run.log" 2>&1 &
echo $! > "$PID_FILE"
sleep 2
# 验证
log "测试 Google..."
HTTP_CODE=$(curl -s --max-time 8 --socks5 127.0.0.1:1080 "https://www.google.com" -o /dev/null -w "%{http_code}")
if [ "$HTTP_CODE" = "200" ]; then
    log "🎉 成功！Google 可访问"
    networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 1080 > /dev/null 2>&1
    log "✅ 系统代理已设置"
else
    log "❌ Google 失败 (HTTP $HTTP_CODE)"
    exit 1
fi

log "=== 完成 ==="