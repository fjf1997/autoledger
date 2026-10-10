import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static const _name = 'auto_ledger.db';
  static const _version = 1;
  static const table = 'records';

  final Database db;

  AppDatabase._(this.db);

  static Future<AppDatabase> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, _name),
      version: _version,
      onCreate: (d, _) async {
        await d.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            type INTEGER NOT NULL,
            merchant TEXT NOT NULL,
            category TEXT NOT NULL,
            ts INTEGER NOT NULL,
            note TEXT,
            pay_method TEXT,
            order_no TEXT,
            raw_text TEXT,
            source TEXT,
            confidence REAL DEFAULT 1,
            created_at INTEGER NOT NULL
          )
        ''');
        await d.execute('CREATE INDEX idx_records_ts ON records(ts)');
        await d.execute('CREATE INDEX idx_records_cat ON records(category)');
      },
    );
    return AppDatabase._(db);
  }

  Future<void> close() => db.close();
}
