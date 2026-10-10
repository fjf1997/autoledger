import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/ledger_repository.dart';
import '../main.dart';
import '../models/category.dart';
import '../models/ledger_record.dart';
import '../utils/format.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late DateTime _month;
  List<CategoryTotal> _cats = [];
  List<MonthTotal> _trend = [];
  double _expense = 0;
  double _income = 0;
  bool _loading = true;
  RecordType _tab = RecordType.expense;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    ledgerVersion.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    ledgerVersion.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => _load();

  DateTime get _from => DateTime(_month.year, _month.month, 1);
  DateTime get _to => DateTime(_month.year, _month.month + 1, 1);

  Future<void> _load() async {
    final repo = context.read<LedgerRepository>();
    final results = await Future.wait<Object>([
      repo.categoryTotals(_from, _to, type: _tab),
      repo.monthlyTrend(6, now: _from),
      repo.sum(_from, _to, RecordType.expense),
      repo.sum(_from, _to, RecordType.income),
    ]);
    if (!mounted) return;
    setState(() {
      _cats = results[0] as List<CategoryTotal>;
      _trend = results[1] as List<MonthTotal>;
      _expense = results[2] as double;
      _income = results[3] as double;
      _loading = false;
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _loading = true;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final total = _cats.fold<double>(0, (s, c) => s + c.total);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftMonth(-1),
            ),
            Text('${_month.year}年${_month.month}月'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Row(
                    children: [
                      _Box('支出', _expense, const Color(0xFFE53935)),
                      const SizedBox(width: 10),
                      _Box('收入', _income, const Color(0xFF43A047)),
                      const SizedBox(width: 10),
                      _Box('结余', _income - _expense, Colors.blueGrey),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<RecordType>(
                    segments: const [
                      ButtonSegment(
                          value: RecordType.expense, label: Text('支出结构')),
                      ButtonSegment(
                          value: RecordType.income, label: Text('收入结构')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) {
                      setState(() {
                        _tab = s.first;
                        _loading = true;
                      });
                      _load();
                    },
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _cats.isEmpty
                          ? const SizedBox(
                              height: 180,
                              child: Center(child: Text('本月暂无数据')),
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  height: 190,
                                  child: PieChart(
                                    PieChartData(
                                      centerSpaceRadius: 42,
                                      sectionsSpace: 2,
                                      sections: _cats.map((c) {
                                        final pct = total <= 0
                                            ? 0
                                            : (c.total / total * 100);
                                        return PieChartSectionData(
                                          value: c.total,
                                          title: pct < 4
                                              ? ''
                                              : '${pct.round()}%',
                                          color:
                                              Color(Category.colorOf(c.category)),
                                          radius: 46,
                                          titleStyle: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._cats.map(
                                  (c) => _CatRow(c: c, total: total),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Text('近 6 个月支出',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 180,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                borderData: FlBorderData(show: false),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval: _interval(),
                                ),
                                titlesData: FlTitlesData(
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (v, meta) {
                                        final i = v.toInt();
                                        if (i < 0 || i >= _trend.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: Text(
                                            '${_trend[i].month}月',
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 44,
                                      getTitlesWidget: (v, meta) => Text(
                                        _short(v),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                ),
                                barGroups: _trend.asMap().entries.map((e) {
                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: e.value.expense,
                                        width: 16,
                                        color: const Color(0xFF43A047),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  double _interval() {
    final max = _trend.fold<double>(0, (s, m) => s > m.expense ? s : m.expense);
    if (max <= 0) return 1;
    return (max / 4).ceilToDouble();
  }

  String _short(double v) {
    if (v >= 10000) return '${(v / 10000).toStringAsFixed(1)}万';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _Box extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _Box(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: color)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                '¥${money(value)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  final CategoryTotal c;
  final double total;
  const _CatRow({required this.c, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total <= 0 ? 0 : c.total / total;
    final color = Color(Category.colorOf(c.category));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, color: color),
          const SizedBox(width: 8),
          Text(c.category, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Text('${c.count} 笔',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const Spacer(),
          Text('¥${money(c.total)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}
