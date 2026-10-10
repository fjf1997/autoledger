import 'package:flutter_test/flutter_test.dart';
import 'package:auto_ledger/models/ledger_record.dart';
import 'package:auto_ledger/ocr/receipt_parser.dart';

void main() {
  group('微信支付账单', () {
    const text = '''
微信支付
-128.50
当前状态 支付成功
支付时间 2024年5月20日 12:30
商品 星巴克咖啡
商户全称 上海星巴克咖啡经营有限公司
支付方式 招商银行储蓄卡(1234)
交易单号 4200001234202405201234567890
''';
    final r = ReceiptParser.parse(text, now: DateTime(2024, 5, 20));
    test('金额', () => expect(r.amount, 128.50));
    test('商户', () => expect(r.merchant, '上海星巴克咖啡经营有限公司'));
    test('时间', () => expect(r.time, DateTime(2024, 5, 20, 12, 30)));
    test('分类', () => expect(r.category, '餐饮'));
    test('方向', () => expect(r.type, RecordType.expense));
    test('单号', () => expect(r.orderNo!.startsWith('420000'), true));
    test('置信度', () => expect(r.confidence > 0.8, true));
  });

  group('支付宝账单', () {
    const text = '''
支付宝
-35.80
交易成功
商品说明 美团外卖订单
收款方 北京三快在线科技有限公司
付款方式 余额宝
交易时间 2024-05-20 12:15
交易号 20240520123456789012
''';
    final r = ReceiptParser.parse(text, now: DateTime(2024, 5, 20));
    test('金额', () => expect(r.amount, 35.80));
    test('商户', () => expect(r.merchant, '北京三快在线科技有限公司'));
    test('时间', () => expect(r.time, DateTime(2024, 5, 20, 12, 15)));
    test('分类', () => expect(r.category, '餐饮'));
  });

  group('银行短信', () {
    const text =
        '【招商银行】您尾号1234的储蓄卡于05月20日12:30向 星巴克 支付人民币128.50元，余额8842.10元。';
    final r = ReceiptParser.parse(text, now: DateTime(2024, 5, 20));
    test('金额取「人民币」后的数字，而非余额', () => expect(r.amount, 128.50));
    test('时间', () => expect(r.time, DateTime(2024, 5, 20, 12, 30)));
    test('分类', () => expect(r.category, '餐饮'));
  });

  group('退款（收入）', () {
    const text = '''
退款成功
+59.00
退款金额 59.00
商品 优衣库外套
退款时间 2024年5月21日 09:12
''';
    final r = ReceiptParser.parse(text, now: DateTime(2024, 5, 21));
    test('金额', () => expect(r.amount, 59.00));
    test('识别为收入', () => expect(r.type, RecordType.income));
    test('分类', () => expect(r.category, '购物'));
  });

  group('交通出行', () {
    const text = '''
滴滴出行
-23.60
快车行程
支付成功
支付时间 2024-05-20 18:42
支付方式 微信支付
''';
    final r = ReceiptParser.parse(text, now: DateTime(2024, 5, 20));
    test('金额', () => expect(r.amount, 23.60));
    test('商户', () => expect(r.merchant, '滴滴出行'));
    test('分类', () => expect(r.category, '交通'));
  });
}
