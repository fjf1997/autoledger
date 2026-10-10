#!/usr/bin/env bash
# Android 打包一键脚本（在本机 macOS / Linux / Windows-GitBash 上运行）
#
#   chmod +x build_android.sh && ./build_android.sh        # 打 debug 包
#   ./build_android.sh release                             # 打 release 包
#
# 产物：build/app/outputs/flutter-apk/app-*.apk
set -euo pipefail

MODE="${1:-debug}"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER="${FLUTTER:-flutter}"

echo "==> 项目目录：$PROJ_DIR"
echo "==> 构建模式：$MODE"

# 0. 环境自检
command -v "$FLUTTER" >/dev/null 2>&1 || {
  echo "❌ 找不到 flutter 命令。请先安装 Flutter SDK 并加入 PATH："
  echo "   https://docs.flutter.dev/get-started/install"
  exit 1
}
echo "==> Flutter 版本：$("$FLUTTER" --version | head -1)"

# 1. 若工程缺少 android/ 原生脚手架，用官方模板生成
if [ ! -f "$PROJ_DIR/android/gradle.properties" ]; then
  echo "==> 未发现 android/ 脚手架，正在生成（只生成一次）…"
  TMP="$(mktemp -d)"
  (cd "$TMP" && "$FLUTTER" create --org com.example --project-name auto_ledger \
      --platforms=android scaffold)
  # 拷入模板中除 lib/ 与 pubspec.yaml 之外的原生文件
  rsync -a --ignore-existing --exclude 'lib' --exclude 'pubspec.yaml' \
        --exclude 'pubspec.lock' --exclude 'test' \
        "$TMP/scaffold/" "$PROJ_DIR/"
  rm -rf "$TMP"
  echo "==> 脚手架已生成，请用仓库中的文件覆盖 android/ 下同名文件"
fi

cd "$PROJ_DIR"

# 2. 装依赖
echo "==> flutter pub get"
"$FLUTTER" pub get

# 3. 同意 Android 许可（首次会自动提示）
if [ -d "${ANDROID_HOME:-$HOME/Android/Sdk}" ]; then
  yes | "${ANDROID_HOME:-$HOME/Android/Sdk}/cmdline-tools/latest/bin/sdkmanager" \
        --licenses >/dev/null 2>&1 || true
fi

# 4. 构建
echo "==> 开始构建 apk（首次会下载 Gradle 与依赖，约 5-15 分钟）"
if [ "$MODE" = "release" ]; then
  "$FLUTTER" build apk --release
else
  "$FLUTTER" build apk --debug
fi

APK_DIR="$PROJ_DIR/build/app/outputs/flutter-apk"
echo
echo "✅ 构建完成，APK 位于："
ls -lh "$APK_DIR"/*.apk

# 5. 若手机已连接 adb，直接安装
if command -v adb >/dev/null 2>&1; then
  DEVICES="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
  if [ -n "$DEVICES" ]; then
    APK="$(ls "$APK_DIR"/*.apk | head -1)"
    echo "==> 检测到设备，正在安装…"
    adb install -r "$APK" && echo "✅ 已安装到手机"
  else
    echo "ℹ️  未检测到已连接的设备，把 APK 传到手机点击安装即可"
  fi
fi
