# Windows 本地构建 APK · 保姆级指南

> GitHub 打不开也能用。全程走**清华 / 阿里云国内镜像**，装完一条命令出包。
> 预计耗时：首次安装环境 1–2 小时（大头是下载），之后每次打包 5–15 分钟。
> 需要磁盘：约 **10GB**（Flutter 1G + Android SDK 5G + Gradle 缓存 3G）。

---

## 第 0 步：解压工程

把 `auto_ledger.zip` 解压到一个**路径不含中文和空格**的地方，例如：

```
C:\dev\auto_ledger
```

⚠️ 别放在 `C:\Users\张三\桌面\我的项目` 这种路径下，Gradle 遇到中文路径会报错。

---

## 第 1 步：装 JDK 17（Gradle 需要）

1. 打开清华镜像（比官网快）：
   https://mirrors.tuna.tsinghua.edu.cn/Adoptium/17/jdk/x64/windows/
2. 下载最新的 `OpenJDK17U-jdk_x64_windows_hotspot_17.0.x_x.msi`
3. 双击安装，一路下一步，**勾选 "Set JAVA_HOME variable"** 和 "Add to PATH"

验证：新开一个 PowerShell / CMD，输入

```
java -version
```

看到 `openjdk version "17..."` 就对了。

---

## 第 2 步：装 Flutter SDK

**方式 A：清华镜像直接下载（推荐，最快）**

1. 打开 https://mirrors.tuna.tsinghua.edu.cn/flutter/releases/stable/windows/
2. 下载最新的 `flutter_windows_3.xx.x-stable.zip`（约 1GB）
3. 解压到 **`C:\src\flutter`**（务必这个路径，官方推荐，别放 Program Files）

**方式 B：git clone（慢，备用）**

```
git clone https://mirrors.tuna.tsinghua.edu.cn/git/flutter-sdk.git C:\src\flutter
```

**加入 PATH**（关键）：

- Win + S 搜「环境变量」→ 编辑系统环境变量 → 环境变量
- 在「用户变量」的 Path 里新增一行：`C:\src\flutter\bin`
- 确定保存

**设置国内镜像**（不然 pub get 会卡死）：
同样在「用户变量」里新建两个变量：

| 变量名 | 值 |
|---|---|
| `PUB_HOSTED_URL` | `https://mirrors.tuna.tsinghua.edu.cn/dart-pub` |
| `FLUTTER_STORAGE_BASE_URL` | `https://mirrors.tuna.tsinghua.edu.cn/flutter` |

验证：新开终端输入

```
flutter doctor
```

首次会下载 Dart SDK，等它跑完。看到 Flutter 版本信息即可，Android 相关的红叉先不管，下一步解决。

---

## 第 3 步：装 Android SDK

**方式 A：装 Android Studio（省事，推荐）**

1. 清华镜像下载：https://mirrors.tuna.tsinghua.edu.cn/android-studio/
2. 安装时一路下一步
3. 首次启动 → More Actions → **SDK Manager**
4. 在 SDK Platforms 勾 **Android 14 (API 34)**
5. 在 SDK Tools 务必勾上这三项：
   - ✅ **Android SDK Command-line Tools (latest)**
   - ✅ **Android SDK Build-Tools**
   - ✅ **Android SDK Platform-Tools**
6. Apply → 等待下载完成

**方式 B：只下命令行工具（省 3GB，适合有经验者）**

清华镜像 https://mirrors.tuna.tsinghua.edu.cn/AndroidSDK/ 下载 commandlinetools，然后：

```
sdkmanager --sdk_root=C:\Android\sdk "platforms;android-34" "build-tools;34.0.0" "platform-tools"
```

**设置环境变量**：

| 变量名 | 值 |
|---|---|
| `ANDROID_HOME` | `C:\Users\你的用户名\AppData\Local\Android\Sdk` |

（在 Android Studio 的 SDK Manager 顶部能看到这个路径，直接复制）
同时在 Path 里加一行 `%ANDROID_HOME%\platform-tools`。

**同意许可**：新开终端执行

```
flutter doctor --android-licenses
```

一路输入 `y` 回车。

再跑 `flutter doctor`，Android 那一行应该变绿了。

---

## 第 4 步：一键构建

打开 CMD / PowerShell，cd 到工程目录：

```
cd C:\dev\auto_ledger
build_android.bat
```

或者**直接双击 `build_android.bat`**。

脚本会自动完成：
检查环境 → 补 gradle 脚手架 → 写入阿里云 Maven 镜像 → `pub get` → 构建 APK

想打 debug 包（装到手机上调试用）：

```
build_android.bat debug
```

**首次构建 10–20 分钟**（在下载 Gradle 和各种依赖），耐心等，中途不要关窗口。

成功后会弹出 APK 所在文件夹。

---

## 第 5 步：装到手机

`build/app/outputs/flutter-apk/` 下会有：

| 文件 | 说明 |
|---|---|
| `app-release.apk` | 通用包，任何手机都能装，体积最大 |
| `app-arm64-v8a-release.apk` | 64 位，现代手机选这个，体积小 40% |

传到手机（微信文件传输助手 / QQ / USB 都行），点开安装，提示"未知来源"时允许。

**装完必做**：打开 App → 设置 → 通知自动记账 → 去授权 → 在系统「通知使用权」里勾选「随手记账」。

也可以 USB 连手机（开 USB 调试）后，脚本会问你要不要直接 `adb install`。

---

## 常见报错

| 报错 | 解决 |
|---|---|
| `'flutter' 不是内部或外部命令` | PATH 没生效，**关掉终端重开**；确认路径是 `C:\src\flutter\bin` |
| `cmdline-tools component is missing` | SDK Manager 里勾上 Android SDK Command-line Tools |
| `Could not resolve com.google.mlkit` | 阿里云镜像没生效，检查 `%USERPROFILE%\.gradle\init.gradle` 是否存在 |
| Gradle 一直卡在下载 | 首次正常，等 10 分钟；超过 20 分钟可换手机热点试试 |
| `Unsupported class file major version` | JDK 版本不对，必须是 **JDK 17**，不是 8 也不是 21 |
| 中文路径报错 | 把工程移到 `C:\dev\auto_ledger` 这种纯英文路径 |
| 装到手机闪退 | 确认手机 Android 6.0+；先打 debug 包看日志 |

---

## 省磁盘的小技巧

只打一个架构的包，体积减半且构建更快：

```
flutter build apk --release --target-platform android-arm64
```

清理 Gradle 缓存（能腾出 2–3GB）：

```
rd /s /q %USERPROFILE%\.gradle\caches
```
