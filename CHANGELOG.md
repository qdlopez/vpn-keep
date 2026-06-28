# Changelog

## v4.4.0 (2026-06-28)

### 📦 便携绿色版
- **Xray 核心内置** — 二进制文件打包到 `bin/` 目录，无需安装 v2rayU 或其他第三方软件
- **自动检测 Xray** — 优先使用 `bin/xray`，其次检测 v2rayU，最后回退到系统 PATH
- **自动检测 Asset** — `geoip.dat`/`geosite.dat` 跟随 Xray 二进制同目录自动加载
- **相对路径** — 工作目录从脚本位置自动推导，不再硬编码绝对路径
- **download_bin.sh** — GitHub clone 用户一键下载 Xray 核心 + geo 数据文件
- **环境变量传参** — Python heredoc 通过 `VPN_WORK_DIR`/`VPN_XRAY_BIN`/`VPN_XRAY_ASSET` 接收路径

### 🌐 真正的多源抓取
- **读取 sources.json** — 从所有启用的订阅源并行抓取（之前只从 clashnode 单源）
- **4协议解析** — vmess + vless + trojan + ss（之前只有 vmess + vless）
- **URL解码** — vless/trojan 参数正确 `urllib.parse.unquote()` 解码
- **协议优先级** — vless+reality > vless+tls > trojan > vless > vmess > ss
- **实测验证** — 429节点 → 去重279 → TCP通过29 → 候选#9 Google HTTP 200 ✅

### 改进
- **stop_vpn.sh** — 停止脚本：PID文件关闭 + pgrep兜底 + 关闭系统代理
- **kill_all_xray** — 同时匹配 `xray` 和 `v2ray` 进程
- **中文 README** — 完整的中文文档
- **.gitignore** — 排除大二进制文件

## v4.3.0 (2026-06-03)

### 问题修复
- **阶段4 全部候选 Google 失败** — 原脚本只测试最快的 1 个节点，TCP 通但 HTTP 不通就全盘失败。v4.3 改为**多候选逐一试**（最多 15 个），首个 Google HTTP 200 即停止。实测前 6 个候选全挂，第 7 个成功。
- **旧 Xray 进程卡死** — 原脚本 `kill $(cat PID_FILE)` 在进程不存在时静默失败，但实际可能有残留 Xray 占用 1080 端口。v4.3 用 `pgrep -f v2ray` 杀干净所有相关进程，先 SIGTERM 再 SIGKILL。
- **工作目录路径不一致** — 旧脚本硬编码 `/Users/lopez/.hermes/vpn-keeper`，实际已迁移到 `~/.hermes/skills/network/vpn-keeper`。

### 新特性
- **多候选 Google 验证** — TCP 测速后取前 15 个候选，逐个生成 Xray 配置 + 启动 + curl Google，首个 HTTP 200 即采纳。
- **协议优先级排序** — vless Reality > vless TLS > vless 普通 > vmess > ss，避免选中大量 Cloudflare CDN 假通节点。
- **VLESS URL 解析修复** — 正确处理 `#` fragment 污染和 URL 编码参数。
- **强制重启兜底** — 全部候选失败时，用候选#0 强制重启再试一次（给 Xray 更多启动时间）。

### 变更详情
| 组件 | 变更 |
|------|------|
| 路径 | `/Users/lopez/.hermes/vpn-keeper` → `~/.hermes/skills/network/vpn-keeper` |
| 候选数 | 1 个 → 最多 15 个 |
| Xray 清理 | `kill $(cat PID)` → `pgrep -f v2ray` + SIGTERM/SIGKILL 两轮 |
| Python 输出 | 进度信息走 stderr，不影响 config 文件 |

## v4.2.0 (之前版本)
- 配置驱动架构（sources.json + settings.json）
- 6 个订阅源
