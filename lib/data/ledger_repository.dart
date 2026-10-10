import '../models/ledger_record.dart';
import 'app_database.dart';

/// 分类汇总
class CategoryTotal {
  final String category;
  final double total;
  final int count;
  CategoryTotal(this.category, this.total, this.count);
}

/// 月度汇总
class MonthTotal {
  final int year;
  final int month;
  final double expense;
  final double income;
  MonthTotal(this.year, this.month, this.expense, this.income);
}

class LedgerRepository {
  final AppDatabase database;
  LedgerRepository(this.database);

  Database get _db => database.db;

  // ─────────── 写入 ───────────
  Future<int> insert(LedgerRecord r) async {
    final map = r.toMap()..remove('id');
    map['created_at'] = DateTime.now().millisecondsSinceEpoch;
    return _db.insert(AppDatabase.table, map);
  }

  Future<int> update(LedgerRecord r) =>
      _db.update(AppDatabase.table, r.toMap()..remove('id'),
          where: 'id = ?', whereArgs: [r.id]);

  Future<int> delete(int id) =>
      _db.delete(AppDatabase.table, where: 'id = ?', whereArgs: [id]);

  Future<void> clearAll() => _db.delete(AppDatabase.table);

  /// 去重保存：同金额 + 同单号（或同分钟 + 同商户）视为重复
  Future<int> insertIfNotDuplicate(LedgerRecord r) async {
    if (r.orderNo != null && r.orderNo!.isNotEmpty) {
      final dup = await _db.query(AppDatabase.table,
          where: 'order_no = ?', whereArgs: [r.orderNo], limit: 1);
      if (dup.isNotEmpty) return -1;
    }
    final start = DateTime(r.time.year, r.time.month, r.time.day, r.time.hour,
            r.time.minute)
        .millisecondsSinceEpoch;
    final dup2 = await _db.query(
      AppDatabase.table,
      where: 'amount = ? AND ts >= ? AND ts < ?',
      whereArgs: [r.amount, start, start + 60000],
      limit: 1,
    );
    if (dup2.isNotEmpty) return -1;
    return insert(r);
  }

  // ─────────── 查询 ───────────
  Future<LedgerRecord?> byId(int id) async {
    final rows = await _db.query(AppDatabase.table,
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LedgerRecord.fromMap(rows.first);
  }

  Future<List<LedgerRecord>> list({
    int limit = 200,
    int offset = 0,
    DateTime? from,
    DateTime? to,
    String? category,
    String? keyword,
    RecordType? type,
  }) async {
    final where = <String>[];
    final args = <Object?>[];
    if (from != null) {
      where.add('ts >= ?');
      args.add(from.millisecondsSinceEpoch);
    }
    if (to != null) {
      where.add('ts < ?');
      args.add(to.millisecondsSinceEpoch);
    }
    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (type != null) {
      where.add('type = ?');
      args.add(type.value);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      where.add('(merchant LIKE ? OR note LIKE ? OR raw_text LIKE ?)');
      final k = '%${keyword.trim()}%';
      args.addAll([k, k, k]);
    }
    final rows = await _db.query(
      AppDatabase.table,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'ts DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(LedgerRecord.fromMap).toList();
  }

  /// 区间内支出 / 收入总额
  Future<double> sum(DateTime from, DateTime to, RecordType type) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS s FROM ${AppDatabase.table} '
      'WHERE ts >= ? AND ts < ? AND type = ?',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, type.value],
    );
    return ((rows.first['s'] as num?) ?? 0).toDouble();
  }

  /// 分类占比
  Future<List<CategoryTotal>> categoryTotals(
    DateTime from,
    DateTime to, {
    RecordType type = RecordType.expense,
  }) async {
    final rows = await _db.rawQuery(
      'SELECT category, COALESCE(SUM(amount),0) AS s, COUNT(*) AS c '
      'FROM ${AppDatabase.table} WHERE ts >= ? AND ts < ? AND type = ? '
      'GROUP BY category ORDER BY s DESC',
      [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch, type.value],
    );
    return rows
        .map((r) => CategoryTotal(
              r['category'] as String,
              (r['s'] as num).toDouble(),
              (r['c'] as num).toInt(),
            ))
        .toList();
  }

  /// 最近 n 个月的趋势
  Future<List<MonthTotal>> monthlyTrend(int months, {DateTime? now}) async {
    final base = now ?? DateTime.now();
    final result = <MonthTotal>[];
    for (var i = months - 1; i >= 0; i--) {
      final y = base.year;
      var m = base.month - i;
      var yy = y;
      while (m <= 0) {
        m += 12;
        yy -= 1;
      }
      final from = DateTime(yy, m, 1);
      final to = DateTime(yy, m + 1, 1);
      final exp = await sum(from, to, RecordType.expense);
      final inc = await sum(from, to, RecordType.income);
      result.add(MonthTotal(yy, m, exp, inc));
    }
    return result;
  }

  /// 导出 CSV 用：全部记录
  Future<List<LedgerRecord>> all() => list(limit: 100000);
}
