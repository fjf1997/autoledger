import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_database.dart';
import 'data/ledger_repository.dart';
import 'models/ledger_record.dart';
import 'ocr/receipt_parser.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'services/notification_inbox.dart';
import 'services/settings_store.dart';

/// 全局数据版本号：任何写入 +1，列表/统计页据此刷新
final ValueNotifier<int> ledgerVersion = ValueNotifier<int>(0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final repo = LedgerRepository(db);
  final settings = await SettingsStore.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<LedgerRepository>.value(value: repo),
        ChangeNotifierProvider<SettingsStore>.value(value: settings),
      ],
      child: const AutoLedgerApp(),
    ),
  );
}

class AutoLedgerApp extends StatelessWidget {
  const AutoLedgerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF2E7D32);
    return MaterialApp(
      title: '随手记账',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  int _index = 0;
  StreamSubscription<String>? _sub;
  final _inbox = NotificationInbox();

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  /// 通知自动记账：收到支付类通知 → 规则解析 → 入库（可撤销）
  void _startListening() {
    _sub?.cancel();
    _sub = _inbox.texts.listen((text) => _handleNotification(text));
  }

  Future<void> _handleNotification(String text) async {
    if (!mounted) return;
    final settings = context.read<SettingsStore>();
    if (!settings.listenNotification) return;

    final result = ReceiptParser.parse(text, now: DateTime.now());
    if (!result.valid) return;
    if (result.confidence < settings.minConfidence) return;

    final repo = context.read<LedgerRepository>();
    final record = result.toRecord(source: RecordSource.notification);
    final id = await repo.insertIfNotDuplicate(record);
    if (id <= 0) return; // 重复
    ledgerVersion.value++;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已自动记账：${record.merchant} ${record.amount.toStringAsFixed(2)} 元',
        ),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () async {
            await repo.delete(id);
            ledgerVersion.value++;
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeScreen(),
      ScanScreen(),
      StatsScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: '账本'),
          NavigationDestination(
              icon: Icon(Icons.document_scanner_outlined),
              selectedIcon: Icon(Icons.document_scanner),
              label: '识图'),
          NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: '统计'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '设置'),
        ],
      ),
    );
  }
}
