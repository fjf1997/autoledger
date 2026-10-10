import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/ledger_record.dart';
import '../utils/format.dart';

class RecordTile extends StatelessWidget {
  final LedgerRecord record;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const RecordTile({
    super.key,
    required this.record,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = record.type == RecordType.expense;
    final color = Color(Category.colorOf(record.category));
    final icon = IconData(Category.iconOf(record.category),
        fontFamily: 'MaterialIcons');

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.14),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        record.merchant,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        '${record.category} · ${timeLabel(record.time)}'
        '${record.source == RecordSource.manual ? '' : ' · ${record.source.label}'}',
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            signedMoney(record),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isExpense ? Colors.black87 : const Color(0xFF2E7D32),
            ),
          ),
          if (record.confidence < 0.99)
            Text(
              '置信 ${(record.confidence * 100).round()}%',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
        ],
      ),
    );
  }
}
