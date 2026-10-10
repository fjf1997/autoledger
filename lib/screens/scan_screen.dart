import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/ledger_repository.dart';
import '../main.dart';
import '../models/ledger_record.dart';
import '../ocr/ocr_provider.dart';
import '../ocr/platform_ocr_provider.dart';
import '../ocr/receipt_parser.dart';
import '../ocr/remote_vision_ocr_provider.dart';
import '../services/settings_store.dart';
import '../utils/format.dart';
import '../widgets/edit_record_sheet.dart';

/// 截图识别页：选图 → OCR → 规则解析 → 人工确认 → 入库
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _paste = TextEditingController();

  File? _image;
  String _ocrText = '';
  ParseResult? _result;
  bool _busy = false;
  String? _error;

  OcrProvider _engine() {
    final s = context.read<SettingsStore>();
    if (s.engineId == 'remote_vision') {
      return RemoteVisionOcrProvider(
        endpoint: s.endpoint,
        apiKey: s.apiKey,
        model: s.model,
      );
    }
    return PlatformOcrProvider();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _ocrText = '';
    });
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 92);
      if (x == null) {
        setState(() => _busy = false);
        return;
      }
      final file = File(x.path);
      if (!mounted) return;
      setState(() => _image = file);

      final engine = _engine();
      final text = await engine.recognize(file);
      if (!mounted) return;
      setState(() {
        _ocrText = text;
        _result = ReceiptParser.parse(text, now: DateTime.now());
        _busy = false;
      });

      final settings = context.read<SettingsStore>();
      if (settings.autoSave &&
          _result != null &&
          _result!.valid &&
          _result!.confidence >= settings.minConfidence) {
        await _save(silent: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  /// 没有原生 OCR 时，把截图文字粘贴进来同样能走通全流程
  Future<void> _pasteText() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('粘贴账单文字',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _paste,
              maxLines: 8,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '把账单截图里的文字粘贴到这里',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, _paste.text),
                child: const Text('开始解析'),
              ),
            ),
          ],
        ),
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _image = null;
      _ocrText = text;
      _result = ReceiptParser.parse(text, now: DateTime.now());
      _error = null;
    });
  }

  Future<void> _save({bool silent = false}) async {
    final r = _result;
    if (r == null || !r.valid) return;
    final repo = context.read<LedgerRepository>();
    final record = r.toRecord(source: RecordSource.screenshot);
    final id = await repo.insertIfNotDuplicate(record);
    ledgerVersion.value++;
    if (!mounted || silent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id > 0
              ? '已入账：${record.merchant} ${record.amount.toStringAsFixed(2)} 元'
              : '这笔好像记过了，已跳过',
        ),
        action: id > 0
            ? SnackBarAction(
                label: '撤销',
                onPressed: () async {
                  await repo.delete(id);
                  ledgerVersion.value++;
                },
              )
            : null,
      ),
    );
    setState(() {
      _result = null;
      _image = null;
      _ocrText = '';
    });
  }

  Future<void> _reviewAndSave() async {
    final r = _result;
    if (r == null || !r.valid) return;
    final edited = await EditRecordSheet.show(
      context,
      initial: r.toRecord(source: RecordSource.screenshot),
      heading: '确认识别结果',
    );
    if (edited == null) return;
    await context.read<LedgerRepository>().insert(edited);
    ledgerVersion.value++;
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已入账')));
    setState(() {
      _result = null;
      _image = null;
      _ocrText = '';
    });
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('截图识别')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('从相册选截图'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('拍一张'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _pasteText,
              icon: const Icon(Icons.content_paste_go_outlined),
              label: const Text('没有识别引擎？粘贴账单文字也能解析'),
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 28),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('正在识别…')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('识别失败',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(_error!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text(
                      '提示：端侧识别需要原生 ML Kit / Vision 支持；'
                      '也可以在设置里配置大模型识别，或直接用「粘贴文字」。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_image != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(_image!, height: 220, fit: BoxFit.contain),
            ),
          ],
          if (r != null) ...[
            const SizedBox(height: 14),
            _ResultCard(result: r),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reviewAndSave,
                    child: const Text('先改再存'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _save(),
                    child: const Text('直接入账'),
                  ),
                ),
              ],
            ),
          ],
          if (_ocrText.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RawTextCard(text: _ocrText),
          ],
          if (!_busy && r == null && _ocrText.isEmpty) ...[
            const SizedBox(height: 40),
            const Center(
              child: Text(
                '选择一张微信 / 支付宝 / 银行账单截图，\n'
                '自动解析出金额、商户、时间和分类。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final ParseResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final valid = result.valid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 18),
                const SizedBox(width: 6),
                const Text('识别结果',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (valid ? Colors.green : Colors.orange)
                        .withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '置信 ${(result.confidence * 100).round()}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: valid ? Colors.green[700] : Colors.orange[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            if (valid) ...[
              Row(
                children: [
                  Text(
                    '${result.type == RecordType.expense ? '-' : '+'}¥ '
                    '${money(result.amount!)}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Chip(
                    label: Text(result.category ?? '其他'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ] else
              const Text(
                '没能识别出金额，请手动填写或换一张更清晰的截图',
                style: TextStyle(color: Colors.orange),
              ),
            _Line('商户', result.merchant ?? '—'),
            _Line(
              '时间',
              result.time == null
                  ? '—'
                  : '${dateLabel(result.time!)} ${timeLabel(result.time!)}',
            ),
            if (result.payMethod != null) _Line('支付', result.payMethod!),
            if (result.orderNo != null) _Line('单号', result.orderNo!),
            if (result.hints.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...result.hints.map(
                (h) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('· ', style: TextStyle(color: Colors.grey)),
                      Expanded(
                        child: Text(
                          h,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String k;
  final String v;
  const _Line(this.k, this.v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(k, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

class _RawTextCard extends StatelessWidget {
  final String text;
  const _RawTextCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('识别原文',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () => copyText(text),
                  child: const Text('复制'),
                ),
              ],
            ),
            Text(
              text,
              style: const TextStyle(fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
