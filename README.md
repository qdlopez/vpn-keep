# VPN Keeper — 代理自动维护工具

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-4.4-green.svg)](CHANGELOG.md)

> 多源订阅抓取 → 节点测速优选 → Google 实测验证 → 自动启动 Xray 代理
>
> 一个开源的代理节点自动维护工具，专为 AI Agent 和开发者设计。

## ✨ 功能特性

- **📦 便携绿色版** — Xray 核心二进制打包在 `bin/` 目录，无需额外安装任何软件
- **🌐 多源聚合** — 从 6+ 个公开订阅源自动抓取节点（GitHub、clashnode、v2rayshare 等）
- **⚡ 智能优选** — 30 线程并发 TCP 测速 + 协议分层排序（vless+reality > trojan > vmess > ss）
- **✅ 真实验证** — 只有 Google 返回 HTTP 200 的节点才会被采用（TCP 能通 ≠ 能转发流量）
- **🔄 自动修复** — 定时检测 + 自动故障转移，代理挂了自动换节点
- **⚙️ 配置驱动** — 新增订阅源或修改参数只需改 JSON，不用动脚本
- **🤖 Agent 就绪** — 结构化为 Hermes Agent Skill，AI 可直接调用

## 🏗️ 工作流程

```
读取配置 → 多源并行抓取 → 解码合并去重 → 30线程TCP测速
    → 协议优先级排序 → 逐候选Google验证 → 首个HTTP 200采纳
    → 生成Xray配置 → 启动代理 → 设置系统SOCKS代理
```

## 🚀 快速开始

### 方式一：便携版（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/qdlopez/vpn-keep.git
cd vpn-keep

# 2. 下载 Xray 核心（约 60MB，包含 xray + geoip.dat + geosite.dat）
bash bin/download_bin.sh

# 3. 运行
bash scripts/vpn_keeper.sh
```

### 方式二：使用已安装的 v2rayU（macOS）

如果你已经安装了 [v2rayU](https://github.com/yanue/V2rayU)，脚本会自动检测并使用其 Xray 核心，无需运行 `download_bin.sh`。

```bash
git clone https://github.com/qdlopez/vpn-keep.git
cd vpn-keep
bash scripts/vpn_keeper.sh
```

### 节点验证工具

```bash
# 单独验证订阅文件中的节点
python3 scripts/validate_nodes.py subs/latest.txt
```

## 📁 目录结构

```
vpn-keep/
├── scripts/
│   ├── vpn_keeper.sh          # 主脚本（便携版，自动检测 Xray）
│   └── validate_nodes.py      # 独立节点测速工具
├── bin/
│   ├── download_bin.sh        # Xray 核心下载脚本
│   ├── xray                   # Xray 二进制（download_bin.sh 下载）
│   ├── geoip.dat              # IP 地理数据库（自动下载）
│   └── geosite.dat            # 域名分类数据库（自动下载）
├── config/
│   ├── sources.json           # ⭐ 订阅源配置（新增源改这里）
│   └── settings.json          # ⭐ 全局参数（改阈值改这里）
├── references/
│   ├── verified-sources.md    # 已验证数据源详情
│   ├── remote-deployment.md   # 远程服务器部署指南
│   └── cdn-false-positive.md  # CDN 假通节点分析
├── subs/                      # 订阅缓存（运行时生成）
├── logs/                      # 运行日志（运行时生成）
├── SKILL.md                   # Hermes Agent Skill 文档
├── CHANGELOG.md               # 版本变更记录
├── LICENSE                    # Apache 2.0
└── README.md                  # 本文件
```

## ⚙️ 配置说明

### 订阅源 `config/sources.json`

```json
[
  {
    "name": "clashnode",
    "url": "https://node.clashnode.top/uploads/{YEAR}/{MONTH}/0-{TODAY}.txt",
    "encoding": "plain",
    "enabled": true
  }
]
```

- **URL 变量**: `{YEAR}` `{MONTH}` `{TODAY}` `{YESTERDAY}` 自动替换为当前日期
- **encoding**: `"plain"` = 一行一个节点 URL；`"base64"` = 整个文件 base64 编码
- 新增源只需在 JSON 数组中添加一条记录

### 全局参数 `config/settings.json`

```json
{
  "socks_port": 1080,           // SOCKS5 代理端口
  "tcp_timeout_ms": 1500,       // TCP 测速超时阈值
  "max_test_nodes": 120,        // 最大测试节点数
  "concurrent_workers": 30,     // 并发测速线程数
  "google_test_timeout": 10,    // Google 验证超时（秒）
  "filter_ipv6": true           // 过滤 IPv6 节点
}
```

## ⏰ 定时任务（可选）

配合 cron 或 Hermes Agent 实现自动维护：

```bash
# 每 10 分钟检测 Google 连通性，失败自动修复
*/10 * * * * bash /path/to/vpn-keep/scripts/vpn_keeper.sh >> /path/to/vpn-keep/logs/cron.log 2>&1
```

## 🔍 诊断命令

```bash
# 检查代理状态
networksetup -getsocksfirewallproxy Wi-Fi

# 测试 Google 连通性
curl -s --socks5 127.0.0.1:1080 "https://www.google.com" -o /dev/null -w "%{http_code}"

# 查看最新日志
ls -lt logs/ | head -5

# 检查 Xray 进程
cat config/xray.pid | xargs ps -p
```

## 📊 已验证的订阅源

| 源 | 编码 | 节点数 | 协议 | 更新频率 |
|----|------|--------|------|----------|
| Pawdroid | base64 | ~14 | vless, trojan | ~6h |
| Au1rxx | base64 | ~92 | vless, trojan, vmess, ss | ~1h |
| xiaoji235 | plain | ~722 | 混合 | ~3h |
| clashnode | plain | ~148 | vless, vmess | 每日 |
| v2rayshare | base64 | ~30 | vless, ss | 每日 |
| github-v2rayfree | plain | ~28 | vless, trojan | ~15min |

详见 [references/verified-sources.md](references/verified-sources.md)

## ⚠️ 核心设计原则

### TCP 能通 ≠ 能转发流量

免费节点大量经过 Cloudflare CDN，TCP 握手延迟极低（50ms）但实际不转发任何流量。**唯一验证标准是 Google 返回 HTTP 200**。

### 协议可靠性排序

| 协议 | Google 通过率 | 说明 |
|------|-------------|------|
| vless+vision+reality | ~70% | 最可靠，Reality 伪装真实 TLS |
| trojan+ws+tls | ~30% | 中等 |
| vless+ws+tls | ~10% | 大量 CDN 假通 |
| vmess+ws | ~5% | 同上 |

## 📝 变更记录

- **v4.4** — 便携绿色版：Xray 二进制打包到 `bin/`，自动检测，无需安装 v2rayU
- **v4.3** — 多候选 Google 验证（15个），Xray 启动前清理残留进程
- **v4.2** — 配置驱动架构（sources.json + settings.json）
- **v4.0** — 多源聚合 + 协议优先级排序

详见 [CHANGELOG.md](CHANGELOG.md)

## 📄 开源协议

Apache License 2.0 — 详见 [LICENSE](LICENSE)

## 🙏 致谢

- [XTLS/Xray-core](https://github.com/XTLS/Xray-core) — Xray 核心
- [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) — Geo 数据
- 所有免费订阅源的维护者
