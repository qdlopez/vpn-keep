#!/bin/bash
# download_bin.sh — 下载 Xray 核心二进制和 geo 数据文件
# 用法: bash bin/download_bin.sh
#
# 下载内容:
#   - xray (Xray-core 二进制)
#   - geoip.dat (IP 地理数据库)
#   - geosite.dat (域名分类数据库)
#
# 支持平台: macOS (darwin-amd64 / darwin-arm64), Linux (linux-amd64)

set -e

BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "📦 目标目录: $BIN_DIR"

# 检测平台
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS-$ARCH" in
    darwin-x86_64)  PLATFORM="macos-64";;
    darwin-arm64)   PLATFORM="macos-arm64-v8a";;
    linux-x86_64)   PLATFORM="linux-64";;
    linux-aarch64)  PLATFORM="linux-arm64-v8a";;
    *)
        echo "❌ 不支持的平台: $OS-$ARCH"
        echo "   支持的平台: macOS (Intel/Apple Silicon), Linux (amd64/arm64)"
        exit 1
        ;;
esac

echo "🖥️  平台: $PLATFORM"

# Xray-core 最新版本
XRAY_VERSION="25.10.15"
XRAY_URL="https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-${PLATFORM}.zip"

# Geo 数据文件
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

# 下载 Xray
echo ""
echo "⬇️  下载 Xray-core v${XRAY_VERSION}..."
if command -v curl &>/dev/null; then
    curl -sL --connect-timeout 30 "$XRAY_URL" -o "$TMP_DIR/xray.zip"
else
    wget -q --timeout=30 "$XRAY_URL" -O "$TMP_DIR/xray.zip"
fi

if [ ! -s "$TMP_DIR/xray.zip" ]; then
    echo "❌ Xray 下载失败！请检查网络或手动下载:"
    echo "   $XRAY_URL"
    exit 1
fi

echo "📂 解压..."
cd "$TMP_DIR"
unzip -o xray.zip -d xray_extracted

# 复制二进制
if [ -f "xray_extracted/xray" ]; then
    cp "xray_extracted/xray" "$BIN_DIR/xray"
    chmod +x "$BIN_DIR/xray"
    echo "✅ Xray 二进制已安装"
else
    echo "❌ 解压后未找到 xray 二进制"
    exit 1
fi

# 下载 geoip.dat
echo ""
echo "⬇️  下载 geoip.dat..."
if command -v curl &>/dev/null; then
    curl -sL --connect-timeout 30 "$GEOIP_URL" -o "$BIN_DIR/geoip.dat"
else
    wget -q --timeout=30 "$GEOIP_URL" -O "$BIN_DIR/geoip.dat"
fi
[ -s "$BIN_DIR/geoip.dat" ] && echo "✅ geoip.dat 已安装" || echo "⚠️ geoip.dat 下载失败（不影响基本功能）"

# 下载 geosite.dat
echo ""
echo "⬇️  下载 geosite.dat..."
if command -v curl &>/dev/null; then
    curl -sL --connect-timeout 30 "$GEOSITE_URL" -o "$BIN_DIR/geosite.dat"
else
    wget -q --timeout=30 "$GEOSITE_URL" -O "$BIN_DIR/geosite.dat"
fi
[ -s "$BIN_DIR/geosite.dat" ] && echo "✅ geosite.dat 已安装" || echo "⚠️ geosite.dat 下载失败（不影响基本功能）"

# 验证
echo ""
echo "🔍 验证..."
"$BIN_DIR/xray" version 2>/dev/null | head -1 || echo "⚠️ xray 二进制无法执行"

echo ""
echo "🎉 完成！文件列表:"
ls -lh "$BIN_DIR/" | grep -E "xray|geo"
echo ""
echo "现在可以运行: bash scripts/vpn_keeper.sh"
