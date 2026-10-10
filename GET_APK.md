# 拿到能直接安装的 APK：云端构建（免本地装环境）

我这边的运行环境没有 Android SDK，编译不出 APK；装一套 Flutter + Android SDK 需要 10GB 以上磁盘和半小时以上配置，所以最省事的办法是**用 GitHub Actions 免费云端构建**——代码推上去，几分钟后在网页上直接下载 APK。

---

## 五步拿到 APK

### 1. 注册 GitHub 账号
没有的话去 github.com 注册一个，免费。

### 2. 新建仓库
右上角 + → **New repository**
- 名字随便，比如 `auto-ledger`
- 选 **Public**（公开仓库才能免费用 Actions 的构建额度）
- 不要勾 "Add a README"
- 点 Create

### 3. 上传代码
在仓库页面点 **uploading an existing file**，把解压后的**所有文件拖进去**（注意要包含隐藏的 `.github` 文件夹）。

> 如果网页上传不支持 `.github` 目录，就在本地用命令行：
> ```bash
> cd auto_ledger
> git init && git add -A && git commit -m "init"
> git remote add origin https://github.com/你的用户名/auto-ledger.git
> git push -u origin main
> ```

### 4. 等待自动构建
上传完点仓库顶部的 **Actions** 标签，会看到一个正在跑的任务（黄灯）。**大约 5–10 分钟**后变绿勾 ✅。

> 第一次跑要点一下确认：Actions 页面会有提示 "Workflow permissions"，点同意即可。

### 5. 下载 APK
绿色的构建任务点进去 → 页面最下方 **Artifacts** 区域 → 点 `auto-ledger-apk` 下载 zip → 解压得到 3 个文件：

| 文件 | 适用 |
|---|---|
| `app-armeabi-v7a-release.apk` | 32 位 ARM（老机型/部分平板） |
| `app-arm64-v8a-release.apk` | **64 位 ARM（绝大多数现代手机，选这个）** |
| `app-v7a-release.apk`… 或 `app-release.apk` | 通用包，任何手机都能装，体积最大 |

把选中的 APK 传到手机（微信/QQ 传文件也行），点开安装。手机提示"未知来源"时允许即可——这是侧载自己应用的正常提示。

---

## 安装后记得授权

打开 App → **设置** → 打开「通知自动记账」→ 点「去授权」→ 在系统「通知使用权」里勾选「随手记账」。

这步 Android 不允许 App 静默开启，必须手动来。授权后微信/支付宝/银行的支付通知就会自动成账。

---

## 以后改代码怎么重新出包

改完代码 push 上去，Actions 自动重新构建：

```bash
git add -A && git commit -m "改了点东西" && git push
```

想在网页手动触发：Actions → Build Android APK → 右侧 **Run workflow**。

---

## 想不经过 GitHub？

那就只能在你自己电脑上装 Flutter SDK 编译（前面 `ANDROID_INSTALL.md` 的方案 A/B）。
另外 **Codemagic**、**Bitrise** 这类Flutter 云构建服务也支持直接连仓库出 APK，操作逻辑差不多。

---

## 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| Actions 一直是黄灯超过 15 分钟 | 正常，首次要下载 Gradle 全套依赖，等等就好 |
| 构建红叉 ❌ | 点进任务看红色步骤的日志；最常见是 `pub get` 版本冲突，把日志发我 |
| Artifacts 里没有文件 | 构建其实失败了，回到 Actions 看日志 |
| 装完闪退 | 先确认手机是 Android 6.0（API 23）以上 |
| 找不到 `.github` 文件夹 | 解压时要显示隐藏文件，或用命令行 git push |
