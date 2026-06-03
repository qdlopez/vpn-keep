# Changelog

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
