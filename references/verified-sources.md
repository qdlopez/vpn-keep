# 已验证的订阅数据源

## 已加入 sources.json 的源（2026-05-31 验证通过）

| 序号 | 名称 | URL | 编码 | 节点数 | 协议分布 | Vision | 更新频率 | 备注 |
|------|------|-----|------|--------|----------|--------|----------|------|
| 1 | **Pawdroid** | `https://raw.githubusercontent.com/Pawdroid/Free-servers/main/sub` | base64 | 14 | vless:7, trojan:6, vmess:1 | ✅ 4个 | ~6h | ⭐17.6k, **当前工作节点来源**, 含 85.234.114.53 |
| 2 | **Au1rxx** | `https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/v2ray-base64.txt` | base64 | 92 | vless:12, trojan:29, vmess:28, ss:23 | ✅ 2个 | ~1h | ⭐59, **HTTP 代理实测验证**（sing-box 推流量确认 204/200） |
| 3 | **xiaoji235** | `https://raw.githubusercontent.com/xiaoji235/airport-free/main/v2ray.txt` | plain | 722 | 混合 | 少量 | ~3h | ⭐501, 聚合多源（含 clashnode 等）, 含 `#` 注释行 |
| 4 | clashnode | `https://node.clashnode.top/uploads/{YEAR}/{MONTH}/0-{TODAY}.txt` | plain | 148 | vless, vmess | 少量 | 每日 | 首行 `#` 注释, CRLF 换行 |
| 5 | v2rayshare | `https://static.v2rayshare.net/{YEAR}/{MONTH}/{TODAY}.txt` | base64 | 30 | vless, ss | 无 | 每日 | 整个文件 base64 编码 |
| 6 | github-v2rayfree | `https://gh-proxy.com/raw.githubusercontent.com/v2raynnodes/v2rayfree/refs/heads/main/v2ray.txt` | plain | 28 | vless, trojan | 少量 | ~15min | gh-proxy 绕过 GitHub 访问限制 |

## 总池规模
- **合并后**: 约 800-1000 原始节点
- **去重后**: 约 400-500 唯一节点
- **TCP 测速有效**: 约 100-150 节点
- **含 vision 协议**: 约 10-20 节点（最可靠）

## 协议可靠性观察

| 协议 | TCP 成功率 | Google HTTP 200 通过率 | 典型延迟 | 说明 |
|------|-----------|----------------------|----------|------|
| **vless+vision+reality** | ~30% | ~70% | 200-400ms | 最可靠，Reality 伪装真实 TLS，极难被检测 |
| **trojan+ws+tls** | ~40% | ~30% | 100-300ms | 中等可靠性 |
| **vless+ws+tls** | ~60% | ~10% | 50-200ms | 大量经过 Cloudflare CDN，能握手但不能转发 |
| **vmess+ws** | ~50% | ~5% | 50-200ms | 同上 |
| **ss** | ~30% | ~5% | 100-500ms | 不稳定 |

**核心结论**: vision/Reality 节点虽然 TCP 延迟较高（200-400ms），但 Google 通过率最高。脚本已按协议分层排序，vision 节点优先测试。
