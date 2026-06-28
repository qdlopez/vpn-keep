#!/bin/bash
# stop_vpn.sh — 彻底停止 VPN Keeper：关闭 Xray 进程 + 关闭系统代理
# 用法: bash scripts/stop_vpn.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="$WORK_DIR/config/xray.pid"

echo "🛑 停止 VPN Keeper..."

# 1. 通过 PID 文件关闭
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        echo "  通过 PID 文件关闭 Xray (PID: $PID)"
        kill "$PID" 2>/dev/null
        sleep 1
    fi
    rm -f "$PID_FILE"
fi

# 2. 兜底：pgrep 扫描所有 xray/v2ray 进程
PIDS=$(pgrep -f "xray" 2>/dev/null; pgrep -f "v2ray" 2>/dev/null | grep -v pgrep)
if [ -n "$PIDS" ]; then
    echo "  发现残留进程，正在清理..."
    for PID in $(echo "$PIDS" | sort -u); do
        if [ -n "$PID" ]; then
            echo "  SIGTERM -> PID $PID"
            kill "$PID" 2>/dev/null
        fi
    done
    sleep 1

    # SIGKILL 兜底
    REMAIN=$(pgrep -f "xray" 2>/dev/null; pgrep -f "v2ray" 2>/dev/null | grep -v pgrep)
    if [ -n "$REMAIN" ]; then
        for PID in $(echo "$REMAIN" | sort -u); do
            if [ -n "$PID" ]; then
                echo "  SIGKILL -> PID $PID"
                kill -9 "$PID" 2>/dev/null
            fi
        done
    fi
fi

# 3. 关闭系统 SOCKS 代理（macOS）
if command -v networksetup &>/dev/null; then
    networksetup -setsocksfirewallproxystate Wi-Fi off > /dev/null 2>&1
    echo "  系统代理已关闭 (Wi-Fi SOCKS)"
fi

# 4. 最终确认
REMAINING=$(pgrep -f "xray" 2>/dev/null; pgrep -f "v2ray" 2>/dev/null | grep -v pgrep)
if [ -z "$REMAINING" ]; then
    echo "✅ Xray 已彻底退出，系统代理已关闭"
else
    echo "⚠️ 仍有进程残留: $REMAINING"
    exit 1
fi
