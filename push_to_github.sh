#!/usr/bin/env bash
# 把工程推到 GitHub，触发云端构建 APK（在电脑上运行，无需安装 git 之外的东西）
#
#   chmod +x push_to_github.sh && ./push_to_github.sh
#
# 运行前准备：在 github.com 网页上新建一个空仓库（Public，不要勾 README）
set -euo pipefail

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJ_DIR"

command -v git >/dev/null 2>&1 || {
  echo "❌ 需要 git。macOS 自带；Windows 请装 https://git-scm.com"
  exit 1
}

echo "=== 把工程推到 GitHub，云端自动生成 APK ==="
echo
read -rp "GitHub 用户名: " USER
read -rp "仓库名（如 auto-ledger）: " REPO

REMOTE="https://github.com/$USER/$REPO.git"

echo
echo "目标仓库：$REMOTE"
echo "（若仓库还没建，请先去 github.com 新建一个 Public 空仓库）"
read -rp "确认继续？[y/N] " GO
[ "$GO" = "y" ] || [ "$GO" = "Y" ] || exit 0

# 初始化并推送（-A 会把隐藏的 .github 一起带上）
if [ ! -d .git ]; then
  git init
  git branch -M main
fi

git add -A

# 确认关键文件已纳入
if ! git ls-files | grep -q '^\.github/workflows/'; then
  echo "⚠️  没检测到 .github/workflows 下的文件，云端不会自动构建！"
  echo "    请确认解压时保留了隐藏文件夹 .github"
  exit 1
fi

git commit -m "auto ledger: init" || echo "（没有新的改动可提交）"

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "$REMOTE"
fi

echo "==> 推送中…（会弹出登录窗口，用 GitHub 账号登录或用 Personal Access Token）"
git push -u origin main

echo
echo "✅ 推送完成！"
echo "接下来：打开 https://github.com/$USER/$REPO/actions"
echo "等 5-10 分钟构建转绿 → 点进任务 → 页面底部 Artifacts → 下载 auto-ledger-apk"
