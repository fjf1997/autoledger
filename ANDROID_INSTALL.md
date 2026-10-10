# Android 安装指南

> 交付的是**源码工程**，不是 APK。需要先在本机装 Flutter SDK 打包，再装到手机。
> 全程预计 30–60 分钟（大头是下载 SDK 和首次 Gradle 编译）。

---

## 方案 A：一键脚本（推荐，macOS / Linux / Git Bash）

```bash
# 1. 装 Flutter SDK（选一个即可）
#    macOS：brew install flutter  官网：https://docs.flutter.dev/get-started/install
#    装完按提示把 flutter 加入 PATH

# 2. 生成原生脚手架（只需一次）
flutter create --org com.example --project-name auto_ledger auto_ledger
#    然后把本仓库的文件覆盖进去：
#    lib/ 整个目录、android/app/src/main/ 整个目录、
#    android/app/build.gradle、pubspec.yaml、analysis_options.yaml

# 3. 一键构建 + 安装
cd auto_ledger
chmod +x build_android.sh
./build_android.sh            # debug 包，调试用
./build_android.sh release    # release 包，日常使用，体积更小
```

脚本会自动完成：`pub get` → 生成缺失脚手架 → 同意 Android 许可 → 构建 → `adb install` 装到已连接手机。

产物路径：`build/app/outputs/flutter-apk/app-*.apk`

---

## 方案 B：手动命令行

```bash
flutter create --org com.example --project-name auto_ledger auto_ledger
# 覆盖文件（同上）
cd auto_ledger
flutter pub get
flutter build apk --release          # 或 --debug
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

只想边写边看效果，可以把手机用 USB 连上（开「USB 调试」）后直接：

```bash
flutter devices        # 确认能识别到手机
flutter run            # 直接装到手机并热重载
```

---

## 方案 C：不打包，先验证功能

不想配环境的话，先用这两条确认识别逻辑是否符合预期：

```bash
python3 tools/verify_rules.py   # 5 个真实账单样本，验证金额/商户/时间/分类
flutter test                    # 同样的 5 组 Dart 单测
```

---

## 安装后必做：给「通知自动记账」授权

这是让 App 全自动的关键一步，**Android 必须在系统设置里手动授权**，App 内无法静默开启：

1. 打开 App → **设置** → 打开「通知自动记账」开关
2. 点「去授权」跳转到系统页（或手动进：设置 → 通知 → **通知使用权 / 通知访问**）
3. 找到「随手记账」打开开关
4. 回到 App，设置页会显示「已授权」

之后微信 / 支付宝 / 银行 / 短信的支付通知就会被自动解析记账，底部会弹出提示，可点「撤销」。

> iOS 无需此步，但 iOS 系统不允许第三方读取通知，该功能仅在 Android 可用。

---

## 常见报错

| 报错 | 解决办法 |
|---|---|
| `cmdline-tools component is missing` | Android Studio → SDK Manager → 勾选 **Android SDK Command-line Tools** |
| `Gradle 下载超时` | 换国内镜像：在 `android/gradle.properties` 加 `systemProp.https.proxyHost` 或使用阿里云 Maven 镜像 |
| `Could not resolve com.google.mlkit:text-recognition-chinese` | 需联网下载 ML Kit；离线环境可先删掉 `android/app/build.gradle` 里该依赖，改用「粘贴文字」模式 |
| 装到手机提示「未知来源」 | 手机设置里允许该来源安装（首次侧载正常现象） |
| release 包安装闪退 | 先打 debug 包定位；确认 `minSdk 23` 与手机系统版本匹配 |

---

## 上架 / 正式分发前

- 换签名：`android/app/build.gradle` 里把 `signingConfig signingConfigs.debug` 替换成自己的 keystore
- 改包名：`flutter create --org com.yourname`，同步改 `MainActivity.kt` 的 `package`
- 缩减体积：`flutter build apk --split-per-abi`（按 CPU 架构分包，体积减少约 40%）
