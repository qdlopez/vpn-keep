#!/usr/bin/env python3
"""
VPN Node Validator - 节点验证工具
用于验证 v2ray/clash 订阅链接中的节点有效性及延迟
"""

import base64
import json
import re
import socket
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

def decode_vmess(url):
    """解析 vmess:// 链接"""
    try:
        b64 = url[8:].strip()
        padding = 4 - len(b64) % 4
        if padding != 4: b64 += '=' * padding
        return json.loads(base64.b64decode(b64))
    except: return None

def parse_links(filepath):
    """从 txt 文件解析节点"""
    nodes = []
    try:
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
    except Exception as e:
        print(f"Parse error: {e}", file=sys.stderr)
    return nodes

def tcp_test(server, port, timeout=2):
    """TCP 连通性测试"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        start = time.time()
        s.connect((server, int(port)))
        s.close()
        return round((time.time()-start)*1000, 1)
    except: return None

def validate_and_rank(sub_path, max_workers=30, timeout=1500):
    """主流程：解析 -> 测速 -> 排序 -> 返回结果"""
    nodes = parse_links(sub_path)
    if not nodes:
        return []

    # 去重
    seen = set()
    unique = []
    for n in nodes:
        key = f"{n['server']}:{n['port']}"
        if key not in seen:
            seen.add(key)
            unique.append(n)

    # 并发测试
    valid = []
    with ThreadPoolExecutor(max_workers=max_workers) as exe:
        futs = {exe.submit(tcp_test, n['server'], n['port']): n for n in unique[:100]} # 限制测试前100个
        for f in as_completed(futs):
            n = futs[f]
            lat = f.result()
            if lat and lat < timeout:
                n['latency'] = lat
                valid.append(n)

    # 按延迟排序
    valid.sort(key=lambda x: x['latency'])
    return valid

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python validate_nodes.py <subscription_txt_path>")
        sys.exit(1)

    result = validate_and_rank(sys.argv[1])
    print(f"Total: {len(result)} valid nodes found.")
    for n in result[:5]:
        print(f"  [{n['latency']}ms] {n['proto']} - {n['server']}:{n['port']}")