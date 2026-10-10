# 随手记账 · 自动记账 App（Flutter + 截图识别）

一个完整的 Flutter 跨平台记账 App：**选一张微信 / 支付宝 / 银行账单截图 → 自动解析出金额、商户、时间、分类 → 一键入账**，还能在 Android 上监听支付通知实现「全自动」记账。数据全部存本机 SQLite，不上传任何服务器。

---

## 一、先跑起来

```bash
# 1. 用官方模板生成原生工程骨架（只需要一次）
flutter create --org com.example --project-name auto_ledger auto_ledger

# 2. 用本项目文件覆盖对应目录（lib/、android/、ios/ 下同名文件直接替换）
#    pubspec.yaml、analysis_options.yaml 也替换

# 3. 装依赖并运行
cd auto_ledger
flutter pub get
flutter run
```

> `flutter create` 会生成 gradle、资源、图标等脚手架；本仓库只提供需要改写的那部分文件（见下方目录结构）。

跑不起来也能先验证解析规则：

```bash
python3 tools/verify_rules.py   # 5 个真实账单样本，全部通过
flutter test                    # Dart 侧同样的 5 组用例
```

---

## 二、功能一览

| 模块 | 能力 |
|---|---|
| 截图识别 | 相册选图 / 拍照 → OCR → 规则解析 → 结果卡片 → 改一改或一键入账 |
| 文本兜底 | 没有 OCR 引擎时，把截图里的字粘贴进来，照样解析成账 |
| 手动记账 | 底部面板填金额、选分类、改时间 |
| 通知自动记账 | Android 端监听微信/支付宝/银行通知，命中即自动成账，支持「撤销」 |
| 账本 | 按月汇总支出/收入/结余，按日分组、搜索、编辑、删除 |
| 统计 | 分类饼图 + 排行，近 6 个月支出柱状图，月份左右切换 |
| 数据 | 导出 CSV（同时复制到剪贴板）、清空 |
| 去重 | 同单号 / 同分钟同金额不会重复记账 |

---

## 三、识别是怎么做的

```
截图 → OcrProvider.recognize() → 纯文本 → ReceiptParser.parse() → ParseResult → 入库
```

**OCR 层是可插拔的**（`lib/ocr/ocr_provider.dart`）：

- `PlatformOcrProvider`：默认，走 MethodChannel 调原生
  - Android：ML Kit Text Recognition（中文，离线免费）
  - iOS：Vision `VNRecognizeTextRequest`（`zh-Hans`）
- `RemoteVisionOcrProvider`：预留的大模型视觉接口，在设置里填 Endpoint / API Key / 模型名即可切换（OpenAI 兼容的 `/v1/chat/completions`），想接自建后端改这一个文件就行。

**解析层是纯规则的**（`lib/ocr/receipt_parser.dart`），不联网、无 Key 也能用：

- 全角转半角、修 OCR 断行
- 金额：先用「付款金额 / 实付 / 人民币」等标签命中，否则逐行打分（负号 +25、货币符号 +30、整行就是数字 +55、像年份 -65、卡号/余额上下文 -60…），取最高分
- 时间：支持 `2024年5月20日 12:30`、`2024-05-20 12:15`、`05月20日12:30`、今天/昨天
- 商户：`商户全称 / 收款方 / 商品说明` 等标签 → 短信句式「向 X 支付」→ 启发式取首个像名称的行
- 方向：退款/工资/到账 → 收入；支付成功/消费 → 支出
- 分类：12 类关键词表加权匹配（命中越长权重越高）
- 输出 0~1 置信度，低于设置阈值就只提示、不自动入账

---

## 四、目录结构

```
lib/
├── main.dart                     App 入口 / 4 个 Tab / 通知自动记账
├── models/
│   ├── ledger_record.dart        记录模型（支出/收入、来源、置信度）
│   └── category.dart             12 个分类 + 关键词表
├── data/
│   ├── app_database.dart         SQLite 建表
│   └── ledger_repository.dart    CRUD + 聚合查询 + 去重
├── ocr/
│   ├── ocr_provider.dart         引擎抽象与注册表
│   ├── platform_ocr_provider.dart端侧 ML Kit / Vision
│   ├── remote_vision_ocr_provider.dart 大模型视觉接口（预留）
│   └── receipt_parser.dart       ★ 规则解析器
├── services/
│   ├── settings_store.dart       设置持久化
│   └── notification_inbox.dart   通知 EventChannel
├── screens/                      home / scan / stats / settings
├── widgets/                      记录条目、编辑面板
└── utils/format.dart             金额、日期、CSV

android/app/src/main/kotlin/.../MainActivity.kt            ML Kit + 通道
android/app/src/main/kotlin/.../LedgerNotificationService.kt 通知抓取
ios/Runner/AppDelegate.swift                               Vision 识别
tools/verify_rules.py             规则自测（无需 Flutter）
test/receipt_parser_test.dart     Dart 单测
sample/账单样本.txt                粘贴测试用样本
```

---

## 五、常见改动

- **加分类 / 调关键词**：`lib/models/category.dart`
- **新增一种账单格式**：在 `receipt_parser.dart` 里加标签词或正则（金额标签、商户标签、时间格式各一行）
- **换识别服务**：实现 `OcrProvider` 并在 `main.dart` 里注册
- **改包名**：`flutter create --org com.yourname`，同时替换 `MainActivity.kt` 的 package
- **上架**：换掉 `android/app/build.gradle` 里的 debug 签名，iOS 在 Xcode 里配置签名

---

## 六、已知限制

- 通知自动记账仅在 **Android** 可用（iOS 不允许第三方读取通知），需用户在系统「通知使用权」里手动授权
- 端侧 OCR 对极模糊、强反光截图识别率会下降，可在设置里切大模型识别
- 规则解析按「最常见账单版式」设计，遇到新 App 版式可能识别不全——结果页会展示置信度和原文，支持手动修正后再存
- 未做多设备同步与云端备份（数据仅本机）

---

MIT License，随便改。
