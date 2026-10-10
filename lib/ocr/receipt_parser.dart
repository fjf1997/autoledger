import '../models/category.dart';
import '../models/ledger_record.dart';

/// 从一段 OCR / 通知文本里解析出的账单要素
class ParseResult {
  final double? amount;
  final String? merchant;
  final DateTime? time;
  final String? category;
  final RecordType type;
  final String? payMethod;
  final String? orderNo;
  final double confidence;
  final List<String> hints;
  final String rawText;

  const ParseResult({
    this.amount,
    this.merchant,
    this.time,
    this.category,
    this.type = RecordType.expense,
    this.payMethod,
    this.orderNo,
    this.confidence = 0,
    this.hints = const [],
    this.rawText = '',
  });

  bool get valid => amount != null && amount! > 0;

  LedgerRecord toRecord({
    RecordSource source = RecordSource.screenshot,
    DateTime? fallbackTime,
  }) {
    return LedgerRecord(
      amount: amount ?? 0,
      type: type,
      merchant: (merchant == null || merchant!.isEmpty) ? '未识别商户' : merchant!,
      category: category ?? Category.other.name,
      time: time ?? fallbackTime ?? DateTime.now(),
      payMethod: payMethod,
      orderNo: orderNo,
      rawText: rawText,
      source: source,
      confidence: confidence,
    );
  }
}

/// 金额候选及其打分
class _AmountCand {
  final double value;
  final int score;
  final bool negative;
  final String raw;
  final int lineIndex;
  _AmountCand(this.value, this.score, this.negative, this.raw, this.lineIndex);
}

/// 纯规则（正则 + 关键词）的账单解析器，无需联网、无需 API Key。
///
/// 覆盖：微信支付账单、支付宝账单、银行短信、云闪付、常见收付款成功页。
class ReceiptParser {
  ReceiptParser._();

  // —— 金额 ——
  /// 带标签的金额：付款金额 / 实付 / 人民币… 优先级最高
  static final RegExp _labelledAmount = RegExp(
    r'(?:付款金额|支付金额|消费金额|交易金额|订单金额|商品金额|实付款?|应付|合计|总计|金额|人民币|人民币元?)'
    r'\s*[:：]?\s*([-+−])?\s*[¥￥]?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
  );

  /// 通用数字（含可选货币符号）
  static final RegExp _plainAmount = RegExp(
    r'([-+−])?\s*[¥￥]?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)',
  );

  /// 需要排除的上下文（数字紧跟这些词，多半是卡号/单号/件数）
  static final RegExp _badPrefix = RegExp(
    r'(?:尾号|卡号|单号|交易号|订单号|流水号|编号|共?[0-9]+件|共?[0-9]+笔|'
    r'优惠|立减|减免|红包|积分|抵扣|券|折扣|剩余|余额|额度|期|笔|件|天|个月)\s*$',
  );

  // —— 时间 ——
  static final RegExp _labelTime = RegExp(
    r'(?:支付时间|交易时间|付款时间|交易日期|日期|时间)\s*[:：]?\s*(.{6,30})',
  );
  static final RegExp _fullDate = RegExp(
    r'(20[0-9]{2})\s*[年\-/\.]\s*([0-9]{1,2})\s*[月\-/\.]\s*([0-9]{1,2})\s*日?'
    r'[\s,]*(?:([0-9]{1,2})\s*[:：]\s*([0-9]{2})(?:\s*[:：]\s*([0-9]{2}))?)?',
  );
  static final RegExp _shortDate = RegExp(
    r'(?:^|[^0-9])([0-9]{1,2})\s*[月\-/]\s*([0-9]{1,2})\s*日?'
    r'[\s,]*(?:([0-9]{1,2})\s*[:：]\s*([0-9]{2})(?:\s*[:：]\s*([0-9]{2}))?)?',
  );
  static final RegExp _relativeDay = RegExp(
    r'(今天|昨天|前天)[\s,]*(?:([0-9]{1,2})\s*[:：]\s*([0-9]{2}))?',
  );

  // —— 商户 ——
  static const List<String> _merchantLabels = [
    '商户全称', '商户名称', '商家名称', '收款商户', '收款方全称', '收款方', '收款单位',
    '付款商户', '交易对方', '对方账户', '对方', '收款人', '商户', '商家',
    '商品说明', '商品名称', '商品详情', '项目名称', '商品', '项目', '店铺名称', '店铺',
  ];

  // —— 其他 ——
  static final RegExp _payMethod = RegExp(
    r'(?:支付方式|付款方式|付款账户|支付账户|支付卡|账户)\s*[:：]?\s*(.+)',
  );
  static final RegExp _orderNo = RegExp(
    r'(?:交易单号|交易号|订单号|流水号|单号|凭证号)\s*[:：]?\s*([0-9A-Za-z]{6,})',
  );

  /// 判定为「收入」的信号
  static final RegExp _incomeSignal = RegExp(
    r'(退款|退货|已退|收入|转入|入账|到账|工资|薪资|薪水|报销|奖金|提成|补贴|'
    r'收款成功|收款到|收到|红包收入|返现|利息|结息|返利)',
  );
  static final RegExp _expenseSignal = RegExp(
    r'(支付成功|付款成功|交易成功|消费|支出|付款|扣款|已付|实付)',
  );

  /// 噪声行：出现这些词的行不参与商户候选
  static final RegExp _noiseLine = RegExp(
    r'(支付成功|交易成功|已完成|处理中|当前状态|交易状态|订单状态|支付方式|付款方式|'
    r'交易时间|支付时间|交易单号|交易号|订单号|流水号|微信支付|支付宝|云闪付|收付款|'
    r'扫一扫|钱包|账单|明细|余额|零钱|查看|详情|完成|安全|客服|投诉)',
  );

  // ══════════════════════════ 主入口 ══════════════════════════
  static ParseResult parse(String rawText, {DateTime? now}) {
    final nowT = now ?? DateTime.now();
    final text = _normalize(rawText);
    final hints = <String>[];

    final amount = _extractAmount(text, hints);
    final time = _extractTime(text, nowT, hints);
    final merchant = _extractMerchant(text, hints);
    final payMethod = _extractPayMethod(text, hints);
    final orderNo = _extractOrderNo(text, hints);
    final type = _inferType(text, amount?.negative);
    final category = _inferCategory(text, merchant, type);

    double conf = 0;
    if (amount != null) conf += 0.45;
    if (merchant != null) conf += 0.22;
    if (time != null) conf += 0.12;
    if (payMethod != null) conf += 0.06;
    if (orderNo != null) conf += 0.05;
    if (category != Category.other.name) conf += 0.05;
    if (conf > 0.99) conf = 0.99;

    return ParseResult(
      amount: amount?.value,
      merchant: merchant,
      time: time,
      category: category,
      type: type,
      payMethod: payMethod,
      orderNo: orderNo,
      confidence: conf,
      hints: hints,
      rawText: rawText,
    );
  }

  // ══════════════════════════ 归一化 ══════════════════════════
  static String _normalize(String src) {
    var s = src;
    // 全角 → 半角
    const full = '　０１２３４５６７８９ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ'
        'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ：－．，￥';
    const half = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        'abcdefghijklmnopqrstuvwxyz:-.,¥';
    for (var i = 0; i < full.length; i++) {
      s = s.replaceAll(full[i], half[i]);
    }
    // 断行修复：标签与值被 OCR 拆成两行时，合并为一行
    s = s.replaceAll(RegExp(r'(：|:)\s*\n\s*'), r'$1');
    // 压缩行内空白
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    return s;
  }

  // ══════════════════════════ 金额 ══════════════════════════
  static _AmountCand? _extractAmount(String text, List<String> hints) {
    final lines = text.split('\n');
    final candidates = <_AmountCand>[];

    // ① 标签命中
    for (var i = 0; i < lines.length; i++) {
      final m = _labelledAmount.firstMatch(lines[i]);
      if (m != null) {
        final v = _toDouble(m.group(2)!);
        if (v != null && v > 0) {
          candidates.add(_AmountCand(
            v,
            120,
            m.group(1) == '-' || m.group(1) == '−',
            m.group(0)!.trim(),
            i,
          ));
          hints.add('金额来自「${m.group(0)!.trim()}」');
        }
      }
    }

    // ② 逐行通用匹配
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      for (final m in _plainAmount.allMatches(line)) {
        final sign = m.group(1);
        final numStr = m.group(2)!;
        final v = _toDouble(numStr);
        if (v == null || v <= 0) continue;

        var score = 0;
        final before = line.substring(0, m.start).trim();
        final after = line.substring(m.end).trim();

        // 前驱上下文过滤
        if (_badPrefix.hasMatch(before)) score -= 60;
        if (before.endsWith('号') || before.endsWith('卡')) score -= 45;
        if (before.contains('单号') || before.contains('订单')) score -= 40;

        // 货币符号 / 单位
        if (m.group(0)!.contains('¥') || m.group(0)!.contains('￥')) score += 30;
        if (after.startsWith('元')) score += 25;
        if (sign == '-' || sign == '−') score += 25;
        if (sign == '+') score += 10;

        // 整行就是金额（截图顶部的大数字）
        final pureNumber = numStr +
            (sign != null && sign.isNotEmpty ? sign : '') +
            (m.group(0)!.contains('¥') ? '¥' : '');
        if (line.replaceAll(RegExp(r'[\s¥￥]'), '') ==
            pureNumber.replaceAll(RegExp(r'[\s¥￥]'), '')) {
          score += 55;
        }

        // 形态
        if (numStr.contains('.')) score += 12;
        if (line.length <= 14) score += 12;
        if (i < 3) score += 12; // 顶部区域
        if (v < 0.01 || v > 1000000) score -= 70;
        final iv = v.roundToDouble();
        if (v == iv && v >= 1900 && v <= 2100) score -= 65; // 像年份
        if (!numStr.contains('.') && v <= 31) score -= 25; // 像日期/小时
        if (before.contains('共') || after.contains('件')) score -= 30;

        candidates.add(_AmountCand(
          v,
          score,
          sign == '-' || sign == '−',
          m.group(0)!.trim(),
          i,
        ));
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    final best = candidates.first;
    if (!hints.any((h) => h.startsWith('金额'))) {
      hints.add('金额取「${best.raw}」（置信分 ${best.score}）');
    }
    return best;
  }

  static double? _toDouble(String s) {
    final v = double.tryParse(s.replaceAll(',', ''));
    if (v == null || !v.isFinite) return null;
    return v;
  }

  // ══════════════════════════ 时间 ══════════════════════════
  static DateTime? _extractTime(String text, DateTime now, List<String> hints) {
    // 优先在「支付时间」标签附近找
    final lm = _labelTime.firstMatch(text);
    if (lm != null) {
      final t = _parseAnyDate(lm.group(1)!, now);
      if (t != null) {
        hints.add('时间来自「${lm.group(0)!.trim()}」');
        return t;
      }
    }
    final t2 = _parseAnyDate(text, now);
    if (t2 != null) hints.add('时间 ${_fmt(t2)}');
    return t2;
  }

  static DateTime? _parseAnyDate(String s, DateTime now) {
    final full = _fullDate.firstMatch(s);
    if (full != null) {
      final y = int.tryParse(full.group(1)!) ?? now.year;
      final mo = int.tryParse(full.group(2)!) ?? 1;
      final d = int.tryParse(full.group(3)!) ?? 1;
      final hh = int.tryParse(full.group(4) ?? '') ?? 0;
      final mm = int.tryParse(full.group(5) ?? '') ?? 0;
      final ss = int.tryParse(full.group(6) ?? '') ?? 0;
      return _safe(y, mo, d, hh, mm, ss);
    }
    final short = _shortDate.firstMatch(s);
    if (short != null) {
      final mo = int.tryParse(short.group(1)!) ?? 1;
      final d = int.tryParse(short.group(2)!) ?? 1;
      final hh = int.tryParse(short.group(3) ?? '') ?? 0;
      final mm = int.tryParse(short.group(4) ?? '') ?? 0;
      return _safe(now.year, mo, d, hh, mm, 0);
    }
    final rel = _relativeDay.firstMatch(s);
    if (rel != null) {
      final base = switch (rel.group(1)) {
        '昨天' => now.subtract(const Duration(days: 1)),
        '前天' => now.subtract(const Duration(days: 2)),
        _ => now,
      };
      final hh = int.tryParse(rel.group(2) ?? '') ?? base.hour;
      final mm = int.tryParse(rel.group(3) ?? '') ?? base.minute;
      return _safe(base.year, base.month, base.day, hh, mm, 0);
    }
    return null;
  }

  static DateTime? _safe(int y, int mo, int d, int hh, int mm, int ss) {
    if (mo < 1 || mo > 12 || d < 1 || d > 31 || hh > 23 || mm > 59) return null;
    try {
      return DateTime(y, mo, d, hh, mm, ss);
    } catch (_) {
      return null;
    }
  }

  static String _fmt(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}'
      '-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ══════════════════════════ 商户 ══════════════════════════
  static String? _extractMerchant(String text, List<String> hints) {
    final lines = text.split('\n');
    for (final label in _merchantLabels) {
      final re = RegExp('$label\\s*[:：]?\\s*(.+)');
      for (final line in lines) {
        final m = re.firstMatch(line);
        if (m != null) {
          var v = m.group(1)!.trim();
          v = v.replaceAll(RegExp(r'\s{2,}'), ' ');
          if (v.isNotEmpty && v.length <= 40) {
            hints.add('商户来自「$label」');
            return v;
          }
        }
      }
    }
    // 短信类：「向 星巴克 支付」「在XX店消费」
    final sms = RegExp(
      r'(?:向|在)\s*([^\s，,。、（(]{2,20}?)\s*(?:支付|付款|消费|支出|成功支付)',
    );
    final sm = sms.firstMatch(text);
    if (sm != null) {
      hints.add('商户来自短信句式：${sm.group(1)}');
      return sm.group(1)!.trim();
    }

    // 退化：取第一行「像名称」的行
    for (final raw in lines) {
      final line = raw.trim();
      if (line.length < 2 || line.length > 30) continue;
      if (_noiseLine.hasMatch(line)) continue;
      if (_plainAmount.hasMatch(line) && !RegExp(r'[\u4e00-\u9fa5]').hasMatch(line)) {
        continue; // 纯数字
      }
      final withoutDigits = line.replaceAll(RegExp(r'[0-9\s:：\-/年月日.]'), '');
      if (withoutDigits.length < 2) continue; // 几乎只剩数字/日期
      hints.add('商户按启发式规则推断：$line');
      return line;
    }
    return null;
  }

  // ══════════════════════════ 支付方式 / 单号 ══════════════════════════
  static String? _extractPayMethod(String text, List<String> hints) {
    final m = _payMethod.firstMatch(text);
    if (m != null) {
      final v = m.group(1)!.trim();
      if (v.isNotEmpty && v.length <= 30) return v;
    }
    final re = RegExp(r'(招商银行|工商银行|建设银行|农业银行|中国银行|交通银行|邮储银行|'
        r'中信银行|浦发银行|兴业银行|民生银行|平安银行|光大银行|华夏银行|广发银行|'
        r'余额宝|零钱通|余额|花呗|借呗|信用卡|微信零钱|支付宝|云闪付|数字人民币)');
    final m2 = re.firstMatch(text);
    return m2?.group(0);
  }

  static String? _extractOrderNo(String text, List<String> hints) {
    final m = _orderNo.firstMatch(text);
    if (m != null) return m.group(1)!.trim();
    final m2 = RegExp(r'[0-9]{16,}(?![0-9])').firstMatch(text);
    return m2?.group(0);
  }

  // ══════════════════════════ 方向 / 分类 ══════════════════════════
  static RecordType _inferType(String text, bool? negative) {
    final income = _incomeSignal.hasMatch(text);
    final expense = _expenseSignal.hasMatch(text);
    if (income && !expense) return RecordType.income;
    if (expense && !income) return RecordType.expense;
    if (income && expense) {
      // 「退款成功」优先判收入；「支付成功」优先判支出
      return text.indexOf('退款') >= 0 && text.indexOf('支付成功') < 0
          ? RecordType.income
          : RecordType.expense;
    }
    if (negative == false && RegExp(r'\+\s*[¥￥]?[0-9]').hasMatch(text)) {
      return RecordType.income;
    }
    return RecordType.expense;
  }

  static String _inferCategory(String text, String? merchant, RecordType type) {
    if (type == RecordType.income) {
      final hit = Category.match(text.toLowerCase());
      return hit == Category.other ? Category.income.name : hit.name;
    }
    final lower = (merchant ?? '') + ' ' + text.toLowerCase();
    return Category.match(lower).name;
  }
}
