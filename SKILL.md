---
name: vpn-keeper
description: 多源订阅抓取（clashnode/v2rayshare/GitHub），配置驱动，协议分层排序，Google HTTP 200 实测验证，启动 Xray 代理。
version: 4.3.0
---

# VPN Keeper Skill

## 📌 目录结构：所有文件统一在 skill 目录下

**所有 vpn-keeper 相关文件（脚本、配置、日志、订阅缓存）必须在 skill 目录内，不得散落在其他位置。**

当前正确路径：`~/.hermes/skills/network/vpn-keeper/`

```
~/.hermes/skills/network/vpn-keeper/     ← Skill 根目录（所有文件都在这里）
├── SKILL.md
├── scripts/
│   ├── vpn_keeper.sh                    ← v4 主脚本（配置驱动）
│   ├── validate_nodes.py                ← 独立测速工具
│   ├── vpn_keeper.sh.bak                ← 旧版备份
│   ├── vpn_keeper_v2.py                 ← v3 Python 版
│   ├── gen_config.py                    ← 旧配置生成器
│   └── gen_config2.py                   ← 旧配置生成器 v2
├── config/
│   ├── sources.json                     ← ⭐ 订阅源配置（新增源改这里）
│   ├── settings.json                    ← ⭐ 全局参数（改阈值改这里）
│   ├── xray.json                        ← Xray 配置（自动生成）
│   ├── xray_backup.json                 ← 稳定备份配置
│   ├── xray.pid                         ← Xray 进程 PID
│   └── candidate_N.json                 ← 测速中间产物
├── subs/                                ← 订阅缓存
│   ├── all_nodes.txt                    ← 合并去重后
│   └── source_*.txt                     ← 各源原始文件
├── knowledge/
│   └── node_sources.md                  ← 节点源元数据
├── logs/
│   ├── autofix.log                      ← 10 分钟检测日志
│   └── YYYYMMDD_HHMMSS.log              ← 每次运行日志
└── references/
    ├── verified-sources.md              ← 已验证数据源详情
    └── remote-deployment.md             ← 远程服务器部署指南
```

**迁移历史**：旧目录 `~/.hermes/vpn-keeper/` 已重命名为 `~/.hermes/vpn-keeper.bak` 保留。
⚠️ **清理旧目录安全原则**：必须先 `find` 对比确认所有文件已迁移，**永远先 `mv` 备份再考虑删除，禁止 `rm -rf`**。

## ⚠️ 修改技能后的标准流程

**每次修改 vpn-keeper 后，必须提交到 GitHub 仓库 `qdlopez/vpn-keep`**：

```bash
cd ~/.hermes/skills/network/vpn-keeper
git add -A
git commit -m "fix: <description>"
# 中国大陆需要走代理推送：
git -c http.proxy=socks5://127.0.0.1:1080 -c https.proxy=socks5://127.0.0.1:1080 push origin main
# 如果代理不可用，先运行 vpn_keeper.sh 恢复代理再推
```

## ⚠️ 路径漂移陷阱

**修改 `scripts/vpn_keeper.sh` 时必须检查所有硬编码路径**。曾出现 SKILL.md 已更新为新路径 `~/.hermes/skills/network/vpn-keeper/`，但脚本内仍残留旧路径 `~/.hermes/vpn-keeper/` 的情况（包括 bash 变量和 Python heredoc 内的绝对路径）。每次改脚本后用 `grep -n '.hermes/' scripts/vpn_keeper.sh` 验证路径一致性。

## 触发条件
- 需要访问外网（Google/Telegram）但代理失效时
- 每 6 小时自动更新节点（定时任务 `vpn-keeper-auto-update`）
- 每 10 分钟自动检测修复（`vpn-auto-fix` 脚本）
- 系统启动后手动运行

## v4.0 配置驱动架构

**核心设计：脚本不改，配置驱动。新增订阅源或修改参数只改 JSON 配置文件。**

```
~/.hermes/skills/network/vpn-keeper/config/
├── sources.json        ← 订阅源列表（新增/删除源只改此文件）
├── settings.json       ← 全局参数（Xray 路径、端口、测速阈值等）
├── xray.json           ← 当前生效的 Xray 配置（脚本自动生成）
├── xray.pid            ← Xray 进程 PID
└── geo*.dat            ← geoip.dat + geosite.dat（脚本自动复制）
```

```
config/sources.json 结构 (6 个已验证源):
[
  { "name": "pawdroid", "url": "https://raw.githubusercontent.com/Pawdroid/Free-servers/main/sub", "encoding": "base64", "enabled": true },
  { "name": "au1rxx", "url": "https://github.com/Au1rxx/free-vpn-subscriptions/raw/main/output/v2ray-base64.txt", "encoding": "base64", "enabled": true },
  { "name": "xiaoji235", "url": "https://raw.githubusercontent.com/xiaoji235/airport-free/main/v2ray.txt", "encoding": "plain", "enabled": true },
  { "name": "clashnode", "url": "https://node.clashnode.top/uploads/{YEAR}/{MONTH}/0-{TODAY}.txt", "encoding": "plain", "enabled": true },
  { "name": "v2rayshare", "url": "https://static.v2rayshare.net/{YEAR}/{MONTH}/{TODAY}.txt", "encoding": "base64", "enabled": true },
  { "name": "github-v2rayfree", "url": "https://gh-proxy.com/raw.githubusercontent.com/v2raynnodes/v2rayfree/refs/heads/main/v2ray.txt", "encoding": "plain", "enabled": true }
]
URL 支持变量替换: {YEAR} {MONTH} {TODAY} {YESTERDAY}
encoding: "plain" = 一行一个节点URL; "base64" = 整个文件 base64 编码需先解码
```

## 核心架构
```
读取配置 → 多源并行抓取 → 解码合并 → 去重 → 30线程TCP测速 → 生成前N个候选配置 → 逐候选实测Google → 首个HTTP 200设为正式 → 设置系统代理
  ↓              ↓              ↓          ↓         ↓                  ↓                    ↓                        ↓                   ↓
sources.json   clashnode +    base64解码  server:  TCP握手           candidate_0..N.json   启动Xray +               复制为xray.json     networksetup
               v2rayshare +   + plain合并  port去重  <1500ms有效      (每个含完整xray配置)   curl Google HTTP_CODE    + 设置系统代理
               github
```

## 核心流程（v4.0 配置驱动）

### 1. 读取配置（不改脚本）
- 脚本自动读取 `config/sources.json` 获取启用的订阅源
- 脚本自动读取 `config/settings.json` 获取 Xray 路径、端口、测速阈值等
- **新增源**: 在 `sources.json` 中添加一行即可
- **改参数**: 编辑 `settings.json`，无需修改脚本

### 2. 多源并行抓取
- 从所有启用的源并行 `curl` 下载订阅
- URL 中的 `{YEAR}`, `{MONTH}`, `{TODAY}`, `{YESTERDAY}` 自动替换
- 编码处理: `base64` 编码的源需先 `tr -d '\n\r ' | base64 -d` 解码
- 合并所有源到 `subs/all_raw.txt`

### 3. 解析 + 去重
- 支持协议: `vmess://`, `vless://`, `trojan://`, `ss://`
- 去重策略: 基于 `server:port` 组合去重
- **过滤 IPv6 地址**（macOS 代理中易超时）

### 4. 并发测速 + 生成候选配置
- **方式**: 30 线程并发 TCP 握手探测（非完整 TLS 协商）
- **阈值**: 延迟 < 1500ms 视为有效
- **测试数量**: 最多测试前 120 个节点
- 按延迟排序，生成前 N 个候选配置

### 5. 逐候选实测 Google（唯一验证标准）
- **⚠️ 核心原则: TCP 握手成功 ≠ 能转发流量 → 唯一验证标准是 Google 返回 HTTP 200**
- TCP 测速后取前 15 个候选（按协议优先级 + 延迟综合排序）
- 逐个启动候选配置对应的 Xray 进程，先 `pgrep -f v2ray` 杀干净旧进程
- 对每个候选执行: `curl -s --max-time 10 --socks5 127.0.0.1:1080 "https://www.google.com" -o /dev/null -w "%{http_code}"`
- 第一个返回 200 的候选被保存为正式配置 `xray.json`
- **全部失败兜底**: 用候选#0 强制重启再试一次（15s 超时）

## 诊断流程（用户报告代理不可用时）

当用户说"无法访问 Google/外网"时，按以下顺序排查，**不要直接假设代理失效**：

```bash
# 1. 先检查 Xray 是否在运行
ps aux | grep -i "v2ray\|xray" | grep -v grep

# 2. 检查系统代理设置
networksetup -getsocksfirewallproxy Wi-Fi

# 3. 用 SOCKS 参数测试 Google（不要用裸 curl）
curl -s --max-time 10 --socks5 127.0.0.1:1080 "https://www.google.com" -o /dev/null -w "%{http_code}"

# 4. 查看 autofix 日志确认实际状态
tail -5 ~/.hermes/skills/network/vpn-keeper/logs/autofix.log
```

**常见误判场景**:
- 用户用终端 `curl https://google.com` 超时 → 这不是代理问题，是 CLI 不走系统代理
- 用户说"没收到通知" → 可能是 WeChat 限流，代理本身可能正常工作
- 用 `networksetup` 确认代理指向 `127.0.0.1:1080` + autofix 日志显示 ✅ = 代理正常

## 关键命令

```bash
# 手动运行完整流程
bash ~/.hermes/skills/network/vpn-keeper/scripts/vpn_keeper.sh

# 快速检测 Google（每10分钟cron）
bash ~/.hermes/scripts/vpn-autofix.sh

# 检查代理状态
networksetup -getsocksfirewallproxy Wi-Fi

# 测试 Google 连通性
curl -s --socks5 127.0.0.1:1080 "https://www.google.com" -o /dev/null -w "%{http_code}"

# 查看当前 Xray 进程
cat ~/.hermes/skills/network/vpn-keeper/config/xray.pid | xargs ps -p

# 查看最新日志
ls -lt ~/.hermes/skills/network/vpn-keeper/logs/ | head -5
```

## 注意事项

### CDN 假通节点
详见 `references/cdn-false-positive.md` — TCP 握手成功 ≠ 能转发流量，需多候选重试。

### 依赖
- v2rayU 已安装在 `/Applications/v2rayU.app`
- 必须使用 v2rayU 自带的 `geosite.dat` 和 `geoip.dat`（路径: `/Applications/v2rayU.app/Contents/Resources/v2ray-core/`）

### 故障排除

#### 🔑 验证逻辑（最重要）
- **TCP 握手成功 ≠ 代理能转发流量**。免费节点大量经过 Cloudflare CDN，TCP 延迟极低（50ms）但实际不转发任何流量
- **唯一验证标准：Google HTTP 200**。TCP 能通过但 Google 返回 000/超时 = 节点无效

#### URL 解析陷阱
- **Fragment 污染**: VLESS/Trojan URL 中 `#` 后面是节点名，**必须先 `split('#')[0]` 再解析 query 参数**
- **URL 编码**: query 参数包含 URL 编码字符，**必须 `urllib.parse.unquote()` 解码**
- **含 `=` 的值**: 参数值中可能包含 `=`，**必须 `split('=', 1)` 只分割第一个 `=`**

#### 订阅编码检测
- **⚠️ 编码检测陷阱**: clashnode 等源首行是 `#` 注释行，`head -1` 检测会误判为 base64。**必须用 `grep -qE '^(vmess|vless|trojan|ss)://'` 检测整个文件**

#### 协议可靠性分层排序
- **问题**: 纯按 TCP 延迟排序会选中大量 Cloudflare CDN 的 ws 节点
- **优先级**: `vless+vision(Reality)` > `trojan` > `vless(ws/tcp)` > `vmess` > `ss`

#### CRLF 处理
- clashnode 等源使用 CRLF 换行符，合并时不 `tr -d '\r'` 会导致节点 URL 末尾带 `\r`

#### Xray 启动前健康检查
- **必须先 `pgrep -f v2ray` 杀干净所有残留进程**，不能只用 `kill $(cat PID_FILE)`
- 原因：旧进程可能 PID 文件丢失但进程仍在，或卡在僵尸状态占用 1080 端口
- 正确流程：SIGTERM → sleep 0.5 → 再 pgrep 确认 → SIGKILL 残留
- v4.3 之前脚本在此处踩过坑，导致"端口被占"或"代理转发异常"

#### Python heredoc 变量展开陷阱
- `python3 << 'PYEOF'` 中单引号阻止 bash 变量展开，`$VAR` 原样传入 Python 会报错
- 正确做法：用 `export VARNAME="$VAR"` 在 bash 导出环境变量，Python 中用 `os.environ['VARNAME']` 读取
- 或者把进度信息走 `sys.stderr`，只有 JSON 配置走 `stdout`（`python3 << 'PYEOF' > config.json` 时，print 全进 config 文件）

#### 脚本修改原则（用户偏好）
- **先跑通，再升级**。修改脚本前必须先用旧版本确认能跑通，再做最小改动
- 不要一次性重写整个脚本，容易引入新 bug 且难以排查
- 改动完成后必须实际运行测试通过，再更新 SKILL.md 和提交

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| 候选全部 Google 000 | 免费节点池质量差 + 只测1个候选 | **v4.3 修复**：TCP测速后取前15个候选逐个验证，首个HTTP 200即采纳。实测前6个全部HTTP 000(CDN假通)，候选#6成功 |
| 用户收不到 cron 成功通知但代理正常 | WeChat/Weixin 消息限流 | 检查 `autofix.log` 确认实际状态 |
| OpenClaw 插件崩溃 | 模块缓存过期 | `systemctl --user restart openclaw-gateway` |
| 候选全部 Google 000 | 免费节点池质量差 | 增加候选数至 25+，检查 vision 节点 |

## 已验证数据源
详见 `references/verified-sources.md`

## 远程服务器部署
详见 `references/remote-deployment.md`
