import 'category.dart';

/// 一笔账的类型：支出 / 收入
enum RecordType {
  expense(0),
  income(1);

  final int value;
  const RecordType(this.value);

  static RecordType fromValue(int v) =>
      v == 1 ? RecordType.income : RecordType.expense;
}

/// 记账来源
enum RecordSource {
  manual('manual', '手动'),
  screenshot('screenshot', '截图识别'),
  notification('notification', '通知抓取'),
  paste('paste', '文本粘贴');

  final String key;
  final String label;
  const RecordSource(this.key, this.label);

  static RecordSource fromKey(String? key) =>
      RecordSource.values.firstWhere(
        (e) => e.key == key,
        orElse: () => RecordSource.manual,
      );
}

class LedgerRecord {
  final int? id;
  final double amount; // 始终为正数，方向由 type 决定
  final RecordType type;
  final String merchant; // 商家 / 商品
  final String category; // 分类
  final DateTime time;
  final String? note;
  final String? payMethod; // 支付方式
  final String? orderNo; // 交易单号
  final String? rawText; // 原始 OCR 文本，便于纠错
  final RecordSource source;
  final double confidence; // 0~1 识别置信度
  final DateTime createdAt;

  const LedgerRecord({
    this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    required this.time,
    this.note,
    this.payMethod,
    this.orderNo,
    this.rawText,
    this.source = RecordSource.manual,
    this.confidence = 1.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 带符号的金额：支出为负
  double get signedAmount => type == RecordType.expense ? -amount : amount;

  factory LedgerRecord.empty() => LedgerRecord(
        amount: 0,
        type: RecordType.expense,
        merchant: '未命名',
        category: Category.other.name,
        time: DateTime.now(),
      );

  LedgerRecord copyWith({
    int? id,
    double? amount,
    RecordType? type,
    String? merchant,
    String? category,
    DateTime? time,
    String? note,
    String? payMethod,
    String? orderNo,
    String? rawText,
    RecordSource? source,
    double? confidence,
    DateTime? createdAt,
  }) {
    return LedgerRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
      time: time ?? this.time,
      note: note ?? this.note,
      payMethod: payMethod ?? this.payMethod,
      orderNo: orderNo ?? this.orderNo,
      rawText: rawText ?? this.rawText,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'amount': amount,
        'type': type.value,
        'merchant': merchant,
        'category': category,
        'ts': time.millisecondsSinceEpoch,
        'note': note,
        'pay_method': payMethod,
        'order_no': orderNo,
        'raw_text': rawText,
        'source': source.key,
        'confidence': confidence,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory LedgerRecord.fromMap(Map<String, Object?> m) => LedgerRecord(
        id: m['id'] as int?,
        amount: (m['amount'] as num).toDouble(),
        type: RecordType.fromValue((m['type'] as num).toInt()),
        merchant: (m['merchant'] as String?) ?? '未命名',
        category: (m['category'] as String?) ?? Category.other.name,
        time: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
        note: m['note'] as String?,
        payMethod: m['pay_method'] as String?,
        orderNo: m['order_no'] as String?,
        rawText: m['raw_text'] as String?,
        source: RecordSource.fromKey(m['source'] as String?),
        confidence: (m['confidence'] as num?)?.toDouble() ?? 1.0,
        createdAt: m['created_at'] == null
            ? DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt())
            : DateTime.fromMillisecondsSinceEpoch(
                (m['created_at'] as num).toInt()),
      );

  @override
  String toString() =>
      '${type == RecordType.expense ? '-' : '+'}${amount.toStringAsFixed(2)} '
      '$merchant [$category]';
}
