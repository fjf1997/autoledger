import 'package:flutter/services.dart';

import '../models/ledger_record.dart';

String money(double v, {bool signed = false}) {
  final s = v.toStringAsFixed(2);
  final withSep = _thousands(s);
  return signed && v > 0 ? '+$withSep' : withSep;
}

String _thousands(String s) {
  final parts = s.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  return parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
}

String dateLabel(DateTime t) {
  final now = DateTime.now();
  final d = DateTime(t.year, t.month, t.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '昨天';
  if (diff == 2) return '前天';
  if (t.year == now.year) return '${t.month}月${t.day}日';
  return '${t.year}年${t.month}月${t.day}日';
}

String timeLabel(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String signedMoney(LedgerRecord r) =>
    r.type == RecordType.expense ? '-${money(r.amount)}' : '+${money(r.amount)}';

String csvOf(Iterable<LedgerRecord> rs) {
  final sb = StringBuffer()
    ..writeln('日期,时间,类型,金额,商户,分类,支付方式,单号,来源');
  for (final r in rs) {
    sb.writeln([
      '${r.time.year}-${r.time.month.toString().padLeft(2, '0')}'
          '-${r.time.day.toString().padLeft(2, '0')}',
      timeLabel(r.time),
      r.type == RecordType.expense ? '支出' : '收入',
      r.amount.toStringAsFixed(2),
      _esc(r.merchant),
      r.category,
      _esc(r.payMethod ?? ''),
      r.orderNo ?? '',
      r.source.label,
    ].join(','));
  }
  return sb.toString();
}

String _esc(String s) =>
    '"${s.replaceAll('"', '""').replaceAll('\n', ' ')}"';

/// 复制到剪贴板并提示
Future<void> copyText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}
