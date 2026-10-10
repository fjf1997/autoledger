@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
REM ============================================================
REM  随手记账 · Windows 一键构建 APK
REM  用法：双击运行，或命令行 build_android.bat [debug^|release]
REM  前置：已按 WINDOWS_BUILD.md 装好 Flutter + Android SDK
REM ============================================================

set MODE=%1
if "%MODE%"=="" set MODE=release

set PROJ_DIR=%~dp0
cd /d "%PROJ_DIR%"

echo ============================================================
echo   随手记账 APK 一键构建  (%MODE%)
echo ============================================================
echo.

REM ---------- 0. 国内镜像（避免下载超时） ----------
set PUB_HOSTED_URL=https://mirrors.tuna.tsinghua.edu.cn/dart-pub
set FLUTTER_STORAGE_BASE_URL=https://mirrors.tuna.tsinghua.edu.cn/flutter
set GRADLE_OPTS=-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true

REM ---------- 1. 检查 Flutter ----------
where flutter >nul 2>nul
if errorlevel 1 (
    echo [错误] 找不到 flutter 命令。
    echo 请先按 WINDOWS_BUILD.md 装好 Flutter 并加入 PATH，然后重开本窗口。
    goto :fail
)
echo [1/6] Flutter 已就绪
flutter --version | findstr /r "." | more +0

REM ---------- 2. 检查 Android SDK ----------
if "%ANDROID_HOME%"=="" (
    if exist "%LOCALAPPDATA%\Android\Sdk" (
        set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
    ) else (
        echo [错误] 未设置 ANDROID_HOME，也找不到默认 SDK 目录。
        echo 请先装 Android SDK，并设置系统环境变量 ANDROID_HOME。
        goto :fail
    )
)
echo [2/6] Android SDK: %ANDROID_HOME%

REM ---------- 3. 补原生脚手架 ----------
if not exist "%PROJ_DIR%android\gradle.properties" (
    echo [3/6] 未发现 android\ 脚手架，正在生成...
    pushd "%TEMP%"
    if exist fl_scaffold rmdir /s /q fl_scaffold
    flutter create --org com.example --project-name auto_ledger --platforms=android fl_scaffold
    if errorlevel 1 (
        popd
        echo [错误] flutter create 失败
        goto :fail
    )
    REM 只补齐缺失文件，不覆盖仓库中已定制的 build.gradle / MainActivity.kt
    xcopy /s /e /y /i /d "%TEMP%\fl_scaffold\*" "%PROJ_DIR%" >nul
    popd
    echo       脚手架已生成
) else (
    echo [3/6] android\ 脚手架已存在，跳过
)

REM ---------- 4. Maven 镜像（阿里云） ----------
echo [4/6] 写入阿里云 Maven 镜像
if not exist "%PROJ_DIR%android\gradle.properties.bak" (
    if exist "%USERPROFILE%\.gradle\init.gradle" (
        echo       检测到已配置的全局镜像，跳过
    ) else (
        if not exist "%USERPROFILE%\.gradle" mkdir "%USERPROFILE%\.gradle"
        (
        echo // 国内镜像：加速 Gradle 依赖下载，由 build_android.bat 自动写入
        echo allprojects {
        echo     repositories {
        echo         maven { url 'https://maven.aliyun.com/repository/google' }
        echo         maven { url 'https://maven.aliyun.com/repository/public' }
        echo         maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        echo         google^(^)
        echo         mavenCentral^(^)
        echo     }
        echo }
        ) > "%USERPROFILE%\.gradle\init.gradle"
        echo       已写入 %USERPROFILE%\.gradle\init.gradle
    )
)

REM ---------- 5. 装依赖 ----------
echo [5/6] flutter pub get
call flutter pub get
if errorlevel 1 (
    echo [错误] pub get 失败
    goto :fail
)

REM ---------- 6. 构建 ----------
echo [6/6] 开始构建 APK（首次约 10-20 分钟，请耐心等待）
echo.
if /i "%MODE%"=="release" (
    call flutter build apk --release
) else (
    call flutter build apk --debug
)
if errorlevel 1 (
    echo.
    echo [错误] 构建失败，把上面的红色报错发我即可定位。
    goto :fail
)

echo.
echo ============================================================
echo   构建成功！
echo ============================================================
echo APK 位置：
dir /b "%PROJ_DIR%build\app\outputs\flutter-apk\*.apk" 2>nul
echo.
echo 完整路径：%PROJ_DIR%build\app\outputs\flutter-apk\
echo.
echo 传到手机点击安装即可。装完记得：
echo   设置 → 通知自动记账 → 去授权 → 勾选「随手记账」
echo.

REM ---------- 若手机已连接，询问是否直接安装 ----------
where adb >nul 2>nul
if not errorlevel 1 (
    adb devices | findstr /r "device$" >nul
    if not errorlevel 1 (
        set /p DOINSTALL=检测到手机，是否直接安装？[y/N] 
        if /i "!DOINSTALL!"=="y" (
            for %%f in ("%PROJ_DIR%build\app\outputs\flutter-apk\*.apk") do adb install -r "%%f"
        )
    )
)

explorer "%PROJ_DIR%build\app\outputs\flutter-apk"
goto :end

:fail
echo.
echo 构建中断。常见原因见 WINDOWS_BUILD.md 的「常见报错」章节。
pause
exit /b 1

:end
pause
