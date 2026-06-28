#!/bin/bash
# VPN Keeper v4.4 - 便携绿色版
# 变更: 自动检测 Xray 二进制(bin/优先), 相对路径, 无需安装 v2rayU

# 自动检测工作目录（脚本所在目录的上一级）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUB_DIR="$WORK_DIR/subs"
LOG_DIR="$WORK_DIR/logs"
CONFIG_DIR="$WORK_DIR/config"
CONFIG_FILE="$CONFIG_DIR/xray.json"
PID_FILE="$CONFIG_DIR/xray.pid"

# 自动检测 Xray 二进制：优先 bin/ 目录，其次 v2rayU，最后系统 PATH
detect_xray() {
    # 1. 项目自带 bin/ 目录（绿色版）
    if [ -x "$WORK_DIR/bin/xray" ]; then
        echo "$WORK_DIR/bin/xray"
        return
    fi
    # 2. v2rayU 应用（macOS 已安装的用户）
    if [ -x "/Applications/v2rayU.app/Contents/Resources/v2ray-core/v2ray" ]; then
        echo "/Applications/v2rayU.app/Contents/Resources/v2ray-core/v2ray"
        return
    fi
    # 3. 系统 PATH
    local p=$(command -v xray 2>/dev/null || command -v v2ray 2>/dev/null)
    if [ -n "$p" ]; then
        echo "$p"
        return
    fi
    echo ""
}

# 自动检测 Xray asset 目录（geoip.dat / geosite.dat 所在目录）
detect_asset() {
    local xray_bin="$1"
    local bin_dir
    bin_dir="$(dirname "$xray_bin")"
    # 1. bin/ 目录下有 geo 文件
    if [ -f "$bin_dir/geoip.dat" ] || [ -f "$bin_dir/geosite.dat" ]; then
        echo "$bin_dir"
        return
    fi
    # 2. v2rayU 的 v2ray-core 目录
    local vu_dir="/Applications/v2rayU.app/Contents/Resources/v2ray-core"
    if [ -f "$vu_dir/geoip.dat" ]; then
        echo "$vu_dir"
        return
    fi
    # 3. 回退到 bin/ 目录
    echo "$WORK_DIR/bin"
}

XRAY_BIN="$(detect_xray)"
XRAY_ASSET="$(detect_asset "$XRAY_BIN")"

mkdir -p "$SUB_DIR" "$LOG_DIR" "$CONFIG_DIR"
LOG="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG"; }

log "=== VPN Keeper v4.4 便携版 启动 ==="
log "工作目录: $WORK_DIR"
log "Xray 二进制: $XRAY_BIN"
log "Asset 目录: $XRAY_ASSET"

if [ -z "$XRAY_BIN" ]; then
    log "❌ 未找到 Xray 二进制！请运行 bin/download_bin.sh 下载，或安装 v2rayU"
    exit 1
fi

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
    YESTERDAY=$(date -v-1d +%Y%m%d)
    V2RAY_URL="https://node.clashnode.top/uploads/${YEAR}/${MONTH}/0-${YESTERDAY}.txt"
    log "订阅: $V2RAY_URL (昨天)"
    curl -sL --connect-timeout 10 "$V2RAY_URL" -o "$SUB_DIR/latest.txt" 2>/dev/null
fi

if [ ! -s "$SUB_DIR/latest.txt" ]; then
    log "❌ 订阅下载失败，使用上次配置"
    exit 0
fi

log "下载完成，开始解析节点..."

XRAY_ASSET_FINAL="$XRAY_ASSET"

# 导出环境变量供 Python 使用
export VPN_WORK_DIR="$WORK_DIR"
export VPN_XRAY_BIN="$XRAY_BIN"
export VPN_XRAY_ASSET="$XRAY_ASSET_FINAL"

python3 << 'PYEOF'
import base64, json, re, socket, time, sys, os, subprocess, signal

def log(msg):
    print(msg, file=sys.stderr)

# 从环境变量读取路径（便携版，不硬编码）
WORK_DIR = os.environ.get('VPN_WORK_DIR', os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONFIG_FILE = os.path.join(WORK_DIR, 'config', 'xray.json')
PID_FILE = os.path.join(WORK_DIR, 'config', 'xray.pid')
XRAY_BIN = os.environ.get('VPN_XRAY_BIN', 'xray')
XRAY_ASSET = os.environ.get('VPN_XRAY_ASSET', os.path.join(WORK_DIR, 'bin'))

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
            line = line.strip().rstrip('\r')
            if line.startswith('vmess://'):
                d = decode_vmess(line)
                if d and d.get('add') and d.get('port'):
                    nodes.append({'proto': 'vmess', 'server': d['add'], 'port': str(d['port']), 'raw': line, 'name': d.get('ps','vmess')})
            elif line.startswith('vless://'):
                m = re.match(r'vless://([^@]+)@([^:]+):(\d+)', line.split('#')[0])
                if m:
                    params = {}
                    if '?' in line.split('#')[0]:
                        qstr = line.split('#')[0].split('?', 1)[1]
                        for q in qstr.split('&'):
                            if '=' in q:
                                k, v = q.split('=', 1)
                                params[k] = v
                    nodes.append({'proto': 'vless', 'server': m.group(2), 'port': m.group(3), 'raw': line, 'name': line.split('#')[-1] if '#' in line else 'vless', 'params': params})
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

def gen_config(node):
    proxy_ob = {"tag": "proxy", "protocol": node['proto']}
    if node['proto'] == 'vmess':
        d = decode_vmess(node['raw'])
        proxy_ob['settings'] = {"vnext": [{"address": d['add'], "port": int(d['port']), "users": [{"id": d['id'], "alterId": int(d.get('aid',0)), "security": d.get('scy','auto')}]}]}
        stream = {"network": d.get('net','tcp')}
        if d.get('tls') == 'tls':
            stream['security'] = 'tls'
            stream['tlsSettings'] = {"serverName": d.get('sni', d['add']), "allowInsecure": True}
        if d.get('net') == 'ws':
            stream['wsSettings'] = {"path": d.get('path','/'), "headers": {"Host": d.get('host','')}}
        proxy_ob['streamSettings'] = stream
    elif node['proto'] == 'vless':
        m = re.match(r'vless://([^@]+)@([^:]+):(\d+)', node['raw'].split('#')[0])
        if m:
            params = node.get('params', {})
            users = [{"id": m.group(1), "encryption": "none"}]
            if params.get('flow'): users[0]['flow'] = params['flow']
            proxy_ob['settings'] = {"vnext": [{"address": m.group(2), "port": int(m.group(3)), "users": users}]}
            stream = {"network": params.get('type','tcp')}
            sec = params.get('security', '')
            if sec == 'tls':
                stream['security'] = 'tls'
                stream['tlsSettings'] = {"serverName": params.get('sni',''), "allowInsecure": True}
            elif sec == 'reality':
                stream['security'] = 'reality'
                stream['realitySettings'] = {"serverName": params.get('sni',''), "publicKey": params.get('pbk',''), "shortId": params.get('sid',''), "fingerprint": params.get('fp','chrome'), "spiderX": "/"}
            if params.get('type') == 'ws':
                stream['wsSettings'] = {"path": params.get('path','/')}
                if params.get('host'):
                    stream['wsSettings']['headers'] = {"Host": params.get('host','')}
            proxy_ob['streamSettings'] = stream

    config = {
        "log": {"loglevel": "warning"},
        "inbounds": [{"port": 1080, "listen": "127.0.0.1", "protocol": "socks", "settings": {"udp": True}}],
        "outbounds": [proxy_ob, {"tag": "direct", "protocol": "freedom", "settings": {}}, {"tag": "block", "protocol": "blackhole", "settings": {}}],
        "routing": {"rules": [
            {"type": "field", "domain": ["geosite:cn"], "outboundTag": "direct"},
            {"type": "field", "ip": ["geoip:cn"], "outboundTag": "direct"},
            {"type": "field", "domain": ["regexp:.*"], "outboundTag": "proxy"}
        ]}
    }
    return config

def kill_all_xray():
    try:
        # 匹配 xray 和 v2ray 进程
        r = subprocess.run(["pgrep", "-f", "xray"], capture_output=True, text=True)
        pids = set(r.stdout.strip().split())
        r2 = subprocess.run(["pgrep", "-f", "v2ray"], capture_output=True, text=True)
        pids.update(r2.stdout.strip().split())
        for pid in pids:
            if pid:
                try: os.kill(int(pid), signal.SIGTERM)
                except: pass
        time.sleep(0.5)
        r = subprocess.run(["pgrep", "-f", "xray"], capture_output=True, text=True)
        pids = set(r.stdout.strip().split())
        r2 = subprocess.run(["pgrep", "-f", "v2ray"], capture_output=True, text=True)
        pids.update(r2.stdout.strip().split())
        for pid in pids:
            if pid:
                try: os.kill(int(pid), signal.SIGKILL)
                except: pass
    except: pass

def test_google(config_dict, timeout=10):
    import tempfile, shutil
    tmp_cfg = tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False)
    json.dump(config_dict, tmp_cfg)
    tmp_cfg.close()

    kill_all_xray()
    time.sleep(0.5)

    env = os.environ.copy()
    env['XRAY_LOCATION_ASSET'] = XRAY_ASSET
    try:
        proc = subprocess.Popen([XRAY_BIN, '-config', tmp_cfg.name],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    except Exception as e:
        os.unlink(tmp_cfg.name)
        return False, str(e), None

    time.sleep(2)
    try:
        r = subprocess.run(['curl', '-s', '--max-time', str(timeout),
                           '--socks5', '127.0.0.1:1080',
                           '-o', '/dev/null', '-w', '%{http_code}',
                           'https://www.google.com'],
                          capture_output=True, text=True, timeout=timeout+5)
        code = r.stdout.strip()
        if code == '200':
            # 成功，保存为正式配置
            shutil.copy2(tmp_cfg.name, CONFIG_FILE)
            with open(PID_FILE, 'w') as f:
                f.write(str(proc.pid))
            os.unlink(tmp_cfg.name)
            return True, "HTTP 200", proc.pid
        else:
            proc.terminate()
            os.unlink(tmp_cfg.name)
            return False, f"HTTP {code}", None
    except Exception as e:
        proc.terminate()
        os.unlink(tmp_cfg.name)
        return False, f"timeout/error: {e}", None

# ---- 主流程 ----
nodes = parse_links(WORK_DIR + '/subs/latest.txt')
seen = set()
unique = []
for n in nodes:
    key = f"{n['server']}:{n['port']}"
    if key not in seen:
        seen.add(key)
        unique.append(n)

log(f"解析 {len(nodes)} 个节点, 去重后 {len(unique)} 个")

# 协议优先级: vless > vmess (vless Reality 节点优先)
def proto_score(n):
    if n['proto'] == 'vless':
        p = n.get('params', {})
        if p.get('security') == 'reality': return 0
        if p.get('security') == 'tls': return 1
        return 2
    return 3

unique.sort(key=proto_score)

# TCP 测速
valid = []
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=30) as exe:
    futs = {exe.submit(tcp_test, n['server'], n['port']): n for n in unique[:120]}
    for f in futs:
        n = futs[f]
        lat = f.result()
        if lat and lat < 1500:
            n['latency'] = lat
            valid.append(n)

valid.sort(key=lambda x: (proto_score(x), x['latency']))
log(f"TCP 测速通过: {len(valid)} 个")

if not valid:
    log("无有效节点")
    sys.exit(1)

# 多候选 Google 验证 (最多15个)
candidates = valid[:15]
log(f"测试前 {len(candidates)} 个候选...")

for i, node in enumerate(candidates):
    cfg = gen_config(node)
    ok, msg, pid = test_google(cfg)
    status = "✅" if ok else "❌"
    log(f"  候选#{i}: {node['server']}:{node['port']} ({node['latency']}ms) {node['proto']} -> {status} {msg}")
    if ok:
        log(f"\n🎉 候选#{i} 成功!")
        sys.exit(0)

# 全部失败
log(f"\n❌ 全部 {len(candidates)} 个候选均失败")
# 最后尝试: 用候选#0 强制重启
log("尝试强制重启候选#0...")
cfg0 = gen_config(candidates[0])
ok, msg, pid = test_google(cfg0, timeout=15)
if ok:
    log(f"✅ 强制重启成功!")
else:
    log(f"❌ 强制重启也失败: {msg}")
    sys.exit(1)
PYEOF

CONFIG_STATUS=$?
if [ $CONFIG_STATUS -ne 0 ]; then
    log "❌ 无有效节点或Google验证失败，保持当前代理运行"
    exit 1
fi

log "✅ 配置已生成并验证通过"

# 设置系统代理
log "设置系统代理..."
networksetup -setsocksfirewallproxy Wi-Fi 127.0.0.1 1080 > /dev/null 2>&1
networksetup -setsocksfirewallproxystate Wi-Fi on > /dev/null 2>&1

# 最终验证
HTTP_CODE=$(curl -s --max-time 8 --socks5 127.0.0.1:1080 "https://www.google.com" -o /dev/null -w "%{http_code}")
if [ "$HTTP_CODE" = "200" ]; then
    log "🎉 成功！Google 可访问 (HTTP 200)"
else
    log "⚠️ 最终验证失败 (HTTP $HTTP_CODE)，但Xray已启动"
fi

log "=== VPN Keeper v4.4 完成 ==="
