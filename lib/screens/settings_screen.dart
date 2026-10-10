import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/ledger_repository.dart';
import '../main.dart';
import '../services/notification_inbox.dart';
import '../services/settings_store.dart';
import '../utils/format.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final repo = context.read<LedgerRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _Section('识别引擎'),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'platform',
                  groupValue: settings.engineId,
                  title: const Text('端侧识别（离线）'),
                  subtitle: const Text('Android 用 ML Kit，iOS 用 Vision，免费且离线'),
                  onChanged: (v) => settings.setEngine(v!),
                ),
                RadioListTile<String>(
                  value: 'remote_vision',
                  groupValue: settings.engineId,
                  title: const Text('大模型识别（联网）'),
                  subtitle: const Text('准确率更高，需填 Endpoint 与 API Key'),
                  onChanged: (v) => settings.setEngine(v!),
                ),
                if (settings.engineId == 'remote_vision')
                  const _RemoteConfigField(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _Section('识别阈值与自动化'),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      const Text('自动入账的最低置信度'),
                      const Spacer(),
                      Text(
                        '${(settings.minConfidence * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: settings.minConfidence,
                  min: 0.3,
                  max: 0.95,
                  divisions: 13,
                  onChanged: (v) => settings.setMinConfidence(v),
                ),
                SwitchListTile(
                  title: const Text('识别后自动保存'),
                  subtitle: const Text('关闭则每次都先让你确认'),
                  value: settings.autoSave,
                  onChanged: (v) => settings.setAutoSave(v),
                ),
                const _NotificationTile(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _Section('数据'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share_outlined),
                  title: const Text('导出 CSV'),
                  subtitle: const Text('生成账单文件并复制到剪贴板'),
                  onTap: () => _export(context, repo),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined),
                  title: const Text('清空全部记录'),
                  textColor: Colors.red,
                  iconColor: Colors.red,
                  onTap: () => _confirmClear(context, repo),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              '随手记账 v1.0.0 · 数据全部保存在本机',
              style: TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, LedgerRepository repo) async {
    final records = await repo.all();
    if (records.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('还没有记录可导出')));
      }
      return;
    }
    final csv = csvOf(records);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/ledger_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);
    await copyText(csv);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${records.length} 条，文件：${file.path}')),
      );
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    LedgerRepository repo,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空全部记录？'),
        content: const Text('该操作不可恢复，建议先导出 CSV。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.clearAll();
    ledgerVersion.value++;
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}

class _RemoteConfigField extends StatefulWidget {
  const _RemoteConfigField();

  @override
  State<_RemoteConfigField> createState() => _RemoteConfigFieldState();
}

class _RemoteConfigFieldState extends State<_RemoteConfigField> {
  late final TextEditingController _endpoint;
  late final TextEditingController _key;
  late final TextEditingController _model;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsStore>();
    _endpoint = TextEditingController(text: s.endpoint);
    _key = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          TextField(
            controller: _endpoint,
            decoration: const InputDecoration(
              labelText: 'Endpoint',
              hintText: 'https://xxx/v1/chat/completions',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: 'gpt-4o-mini / qwen-vl-max',
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.read<SettingsStore>().setRemoteConfig(
                    endpoint: _endpoint.text,
                    apiKey: _key.text,
                    model: _model.text,
                  ),
              child: const Text('保存配置'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile();

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  final _inbox = NotificationInbox();
  bool? _granted;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final g = await _inbox.hasPermission();
    if (mounted) setState(() => _granted = g);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final granted = _granted;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('通知自动记账（Android）'),
          subtitle: Text(
            granted == null
                ? '读取支付类通知，自动成账'
                : granted
                    ? '已授权，微信/支付宝/银行通知会自动记账'
                    : '尚未授予「通知使用权」',
          ),
          value: settings.listenNotification,
          onChanged: (v) => settings.setListenNotification(v),
        ),
        if (granted == false)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await _inbox.openPermissionSettings();
                  await Future<void>.delayed(const Duration(seconds: 1));
                  await _check();
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('去授权'),
              ),
            ),
          ),
      ],
    );
  }
}
