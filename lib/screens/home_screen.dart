import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ledger_repository.dart';
import '../main.dart';
import '../models/ledger_record.dart';
import '../utils/format.dart';
import '../widgets/edit_record_sheet.dart';
import '../widgets/record_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  List<LedgerRecord> _records = [];
  double _expense = 0;
  double _income = 0;
  bool _loading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    ledgerVersion.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    ledgerVersion.removeListener(_onDataChanged);
    _search.dispose();
    super.dispose();
  }

  void _onDataChanged() => _load();

  Future<void> _load() async {
    final repo = context.read<LedgerRepository>();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 1);

    final results = await Future.wait<Object>([
      repo.list(
        limit: 300,
        keyword: _keyword.trim().isEmpty ? null : _keyword.trim(),
      ),
      repo.sum(from, to, RecordType.expense),
      repo.sum(from, to, RecordType.income),
    ]);

    if (!mounted) return;
    setState(() {
      _records = results[0] as List<LedgerRecord>;
      _expense = results[1] as double;
      _income = results[2] as double;
      _loading = false;
    });
  }

  Future<void> _confirmDelete(LedgerRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除这笔账？'),
        content: Text('${r.merchant} ${money(r.amount)} 元'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await context.read<LedgerRepository>().delete(r.id!);
    ledgerVersion.value++;
  }

  Future<void> _edit(LedgerRecord r) async {
    final updated = await EditRecordSheet.show(context, initial: r);
    if (updated == null) return;
    await context.read<LedgerRepository>().update(updated);
    ledgerVersion.value++;
  }

  Future<void> _addManual() async {
    final record = await EditRecordSheet.show(context);
    if (record == null) return;
    await context.read<LedgerRepository>().insert(record);
    ledgerVersion.value++;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已记录')));
  }

  Map<String, List<LedgerRecord>> get _grouped {
    final map = <String, List<LedgerRecord>>{};
    for (final r in _records) {
      map.putIfAbsent(dateLabel(r.time), () => []).add(r);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final month = DateTime.now().month;
    final groups = _grouped;

    return Scaffold(
      appBar: AppBar(
        title: const Text('随手记账'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            _SummaryCard(
              month: month,
              expense: _expense,
              income: _income,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: '搜索商户 / 备注',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _keyword = '');
                            _load();
                          },
                        ),
                ),
                onSubmitted: (v) {
                  setState(() => _keyword = v);
                  _load();
                },
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: Text('还没有记录，去「识图」或点右下角记一笔')),
              )
            else
              ...groups.entries.map(
                (e) => _DaySection(
                  title: e.key,
                  records: e.value,
                  onEdit: _edit,
                  onDelete: _confirmDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int month;
  final double expense;
  final double income;

  const _SummaryCard({
    required this.month,
    required this.expense,
    required this.income,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF43A047), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$month 月支出',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '¥ ${money(expense)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat('收入', income),
              const SizedBox(width: 28),
              _MiniStat('结余', income - expense),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  const _MiniStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          '¥ ${money(value)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  final String title;
  final List<LedgerRecord> records;
  final ValueChanged<LedgerRecord> onEdit;
  final ValueChanged<LedgerRecord> onDelete;

  const _DaySection({
    required this.title,
    required this.records,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dayTotal = records.fold<double>(
      0,
      (sum, r) => sum + (r.type == RecordType.expense ? -r.amount : r.amount),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
          child: Row(
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${dayTotal >= 0 ? '+' : '-'}¥${money(dayTotal.abs())}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: records
                .map(
                  (r) => RecordTile(
                    record: r,
                    onTap: () => onEdit(r),
                    onLongPress: () => onDelete(r),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
