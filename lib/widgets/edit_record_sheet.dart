import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/ledger_record.dart';
import '../utils/format.dart';

/// 新增 / 编辑一笔账的底部面板（手动记账与识别结果纠错共用）
class EditRecordSheet extends StatefulWidget {
  final LedgerRecord? initial;
  final String? heading;

  const EditRecordSheet({super.key, this.initial, this.heading});

  /// 返回 null 表示用户取消
  static Future<LedgerRecord?> show(
    BuildContext context, {
    LedgerRecord? initial,
    String? heading,
  }) {
    return showModalBottomSheet<LedgerRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: EditRecordSheet(initial: initial, heading: heading),
      ),
    );
  }

  @override
  State<EditRecordSheet> createState() => _EditRecordSheetState();
}

class _EditRecordSheetState extends State<EditRecordSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _merchant;
  late final TextEditingController _note;
  late RecordType _type;
  late String _category;
  late DateTime _time;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _amount = TextEditingController(
      text: r == null ? '' : r.amount.toStringAsFixed(2),
    );
    _merchant = TextEditingController(text: r?.merchant ?? '');
    _note = TextEditingController(text: r?.note ?? '');
    _type = r?.type ?? RecordType.expense;
    _category = r?.category ?? Category.other.name;
    _time = r?.time ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _time,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_time),
    );
    if (t == null) return;
    setState(() {
      _time = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请填写有效金额')));
      return;
    }
    final merchant = _merchant.text.trim().isEmpty
        ? '未命名'
        : _merchant.text.trim();
    final base = widget.initial;
    final record = (base ?? LedgerRecord.empty()).copyWith(
      amount: amount,
      merchant: merchant,
      type: _type,
      category: _category,
      time: _time,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    Navigator.pop(context, record);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.heading ?? (editing ? '编辑这笔账' : '手动记一笔'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          SegmentedButton<RecordType>(
            segments: const [
              ButtonSegment(value: RecordType.expense, label: Text('支出')),
              ButtonSegment(value: RecordType.income, label: Text('收入')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _amount,
                  autofocus: widget.initial == null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: '金额',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    '${dateLabel(_time)}\n${timeLabel(_time)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _merchant,
            decoration: const InputDecoration(
              labelText: '商户 / 说明',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          const Text('分类', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: Category.all.map((c) {
              final selected = c.name == _category;
              return ChoiceChip(
                label: Text(c.name),
                selected: selected,
                selectedColor: Color(c.colorValue).withOpacity(0.18),
                onSelected: (_) => setState(() => _category = c.name),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: Text(editing ? '保存修改' : '记下来'),
          ),
        ],
      ),
    );
  }
}
