#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
规则自测：用与 lib/ocr/receipt_parser.dart 完全相同的正则，
在常见账单文本上验证金额 / 时间 / 商户 / 分类是否提取正确。

本机没装 Flutter 也能跑：
    python3 tools/verify_rules.py
"""
import re
import sys
from datetime import datetime

# ─────────── 与 Dart 端保持一致的正则 ───────────
LABELLED_AMOUNT = re.compile(
    r'(?:付款金额|支付金额|消费金额|交易金额|订单金额|商品金额|实付款?|应付|合计|总计|金额|人民币|人民币元?)'
    r'\s*[:：]?\s*([-+−])?\s*[¥￥]?\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)'
)
PLAIN_AMOUNT = re.compile(
    r'([-+−])?\s*[¥￥]?\s*([0-9]{1,3}(?:,[0-9]{3})+(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)'
)
BAD_PREFIX = re.compile(
    r'(?:尾号|卡号|单号|交易号|订单号|流水号|编号|共?[0-9]+件|共?[0-9]+笔|'
    r'优惠|立减|减免|红包|积分|抵扣|券|折扣|剩余|余额|额度|期|笔|件|天|个月)\s*$'
)
FULL_DATE = re.compile(
    r'(20[0-9]{2})\s*[年\-/\.]\s*([0-9]{1,2})\s*[月\-/\.]\s*([0-9]{1,2})\s*日?'
    r'[\s,]*(?:([0-9]{1,2})\s*[:：]\s*([0-9]{2})(?:\s*[:：]\s*([0-9]{2}))?)?'
)
SHORT_DATE = re.compile(
    r'(?:^|[^0-9])([0-9]{1,2})\s*[月\-/]\s*([0-9]{1,2})\s*日?'
    r'[\s,]*(?:([0-9]{1,2})\s*[:：]\s*([0-9]{2})(?:\s*[:：]\s*([0-9]{2}))?)?'
)
LABEL_TIME = re.compile(r'(?:支付时间|交易时间|付款时间|交易日期|日期|时间)\s*[:：]?\s*(.{6,30})')
ORDER_NO = re.compile(r'(?:交易单号|交易号|订单号|流水号|单号|凭证号)\s*[:：]?\s*([0-9A-Za-z]{6,})')

MERCHANT_LABELS = [
    '商户全称', '商户名称', '商家名称', '收款商户', '收款方全称', '收款方', '收款单位',
    '付款商户', '交易对方', '对方账户', '对方', '收款人', '商户', '商家',
    '商品说明', '商品名称', '商品详情', '项目名称', '商品', '项目', '店铺名称', '店铺',
]

CATEGORY_KEYWORDS = {
    '餐饮': ['美团', '饿了么', '外卖', '星巴克', '瑞幸', '麦当劳', '肯德基', '海底捞',
             '喜茶', '奈雪', '蜜雪冰城', '咖啡', '奶茶', '餐饮', '食品', '餐厅'],
    '交通': ['滴滴', '高德', '出租', '网约车', '地铁', '公交', '高铁', '12306', '机票',
             '加油', '停车', 'etc', '共享单车', '哈啰', '青桔', '打车', '出行'],
    '购物': ['淘宝', '天猫', '京东', '拼多多', '唯品会', '超市', '沃尔玛', '盒马',
             '优衣库', '小米', '苹果', 'apple', '服饰', '数码', '家电'],
    '娱乐': ['电影', '影院', 'ktv', '游戏', 'steam', '爱奇艺', 'bilibili', 'b站',
             '网易云', '会员', '健身', '旅游', '酒店', '携程'],
    '居住': ['房租', '租金', '物业', '水费', '电费', '燃气', '宽带', '水电'],
    '医疗': ['医院', '药房', '药店', '诊所', '体检', '挂号'],
    '教育': ['学费', '书店', '课程', '培训', '考试', '图书', '网课'],
    '通讯': ['话费', '流量', '中国移动', '中国联通', '中国电信'],
    '日用': ['日用', '家居', '清洁', '洗护', '文具'],
    '转账': ['转账', '收款', '红包', '亲属卡', '扫一扫'],
    '理财': ['余额宝', '零钱通', '基金', '理财', '保险', '信用卡', '还款', '花呗'],
    '收入': ['工资', '薪水', '报销', '退款', '退货', '转入', '奖金', '利息'],
}


def normalize(src: str) -> str:
    full = '　０１２３４５６７８９ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' \
           'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ：－．，￥'
    half = ' 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' \
           'abcdefghijklmnopqrstuvwxyz:-.,¥'
    for f, h in zip(full, half):
        src = src.replace(f, h)
    src = re.sub(r'(：|:)\s*\n\s*', r'\1', src)
    return re.sub(r'[ \t]+', ' ', src)


def pick_amount(text: str):
    cands = []
    lines = text.split('\n')
    for i, line in enumerate(lines):
        m = LABELLED_AMOUNT.search(line)
        if m:
            v = float(m.group(2).replace(',', ''))
            if v > 0:
                cands.append((v, 120, m.group(0).strip()))
    for i, line in enumerate(lines):
        line = line.strip()
        if not line:
            continue
        for m in PLAIN_AMOUNT.finditer(line):
            num = m.group(2)
            sign = m.group(1)
            v = float(num.replace(',', ''))
            if v <= 0:
                continue
            score = 0
            before = line[:m.start()].strip()
            after = line[m.end():].strip()
            if BAD_PREFIX.search(before):
                score -= 60
            if before.endswith('号') or before.endswith('卡'):
                score -= 45
            if '¥' in m.group(0) or '￥' in m.group(0):
                score += 30
            if after.startswith('元'):
                score += 25
            if sign in ('-', '−'):
                score += 25
            if sign == '+':
                score += 10
            if line.replace(' ', '').replace('¥', '').replace('￥', '') == \
                    (num + (sign or '')).replace(' ', ''):
                score += 55
            if '.' in num:
                score += 12
            if len(line) <= 14:
                score += 12
            if i < 3:
                score += 12
            if v < 0.01 or v > 1000000:
                score -= 70
            if v == int(v) and 1900 <= v <= 2100:
                score -= 65
            if '.' not in num and v <= 31:
                score -= 25
            cands.append((v, score, m.group(0).strip()))
    if not cands:
        return None
    cands.sort(key=lambda c: c[1], reverse=True)
    return cands[0]


def pick_time(text: str, now: datetime):
    lm = LABEL_TIME.search(text)
    seg = lm.group(1) if lm else text
    m = FULL_DATE.search(seg) or (FULL_DATE.search(text) if lm else None)
    if m:
        return datetime(
            int(m.group(1)), int(m.group(2)), int(m.group(3)),
            int(m.group(4) or 0), int(m.group(5) or 0),
        )
    m = SHORT_DATE.search(seg) or (SHORT_DATE.search(text) if lm else None)
    if m:
        return datetime(now.year, int(m.group(1)), int(m.group(2)),
                        int(m.group(3) or 0), int(m.group(4) or 0))
    return None


def pick_merchant(text: str):
    for label in MERCHANT_LABELS:
        for line in text.split('\n'):
            m = re.search(label + r'\s*[:：]?\s*(.+)', line)
            if m:
                v = m.group(1).strip()
                if v and len(v) <= 40:
                    return v
    sm = SMS_MERCHANT.search(text)
    if sm:
        return sm.group(1).strip()
    for line in text.split('\n'):
        line = line.strip()
        if not (2 <= len(line) <= 30):
            continue
        if re.search(r'[0-9]{4}', line):
            continue
        if re.search(r'[一-鿿]', line):
            return line
    return None


SMS_MERCHANT = re.compile(r'(?:向|在)\s*([^\s，,。、（(]{2,20}?)\s*(?:支付|付款|消费|支出|成功支付)')


def pick_category(text: str, merchant):
    low = (merchant or '') + ' ' + text.lower()
    best, best_score = '其他', 0
    for cat, keys in CATEGORY_KEYWORDS.items():
        score = sum(len(k) for k in keys if k in low)
        if score > best_score:
            best, best_score = cat, score
    return best


def parse(text: str, now=datetime(2024, 5, 20)):
    t = normalize(text)
    amt = pick_amount(t)
    return {
        'amount': amt[0] if amt else None,
        'amount_from': amt[2] if amt else None,
        'time': pick_time(t, now),
        'merchant': pick_merchant(t),
        'category': pick_category(t, pick_merchant(t)),
        'order_no': (ORDER_NO.search(t).group(1) if ORDER_NO.search(t) else None),
    }


SAMPLES = [
    {
        'name': '微信支付',
        'text': """微信支付
-128.50
当前状态 支付成功
支付时间 2024年5月20日 12:30
商品 星巴克咖啡
商户全称 上海星巴克咖啡经营有限公司
支付方式 招商银行储蓄卡(1234)
交易单号 4200001234202405201234567890""",
        'expect': {'amount': 128.5, 'merchant': '上海星巴克咖啡经营有限公司',
                   'time': datetime(2024, 5, 20, 12, 30), 'category': '餐饮'},
    },
    {
        'name': '支付宝',
        'text': """支付宝
-35.80
交易成功
商品说明 美团外卖订单
收款方 北京三快在线科技有限公司
付款方式 余额宝
交易时间 2024-05-20 12:15
交易号 20240520123456789012""",
        'expect': {'amount': 35.8, 'merchant': '北京三快在线科技有限公司',
                   'time': datetime(2024, 5, 20, 12, 15), 'category': '餐饮'},
    },
    {
        'name': '银行短信（金额 vs 余额）',
        'text': '【招商银行】您尾号1234的储蓄卡于05月20日12:30向 星巴克 '
                '支付人民币128.50元，余额8842.10元。',
        'expect': {'amount': 128.5, 'category': '餐饮', 'merchant': '星巴克',
                   'time': datetime(2024, 5, 20, 12, 30)},
    },
    {
        'name': '退款收入',
        'text': """退款成功
+59.00
退款金额 59.00
商品 优衣库外套
退款时间 2024年5月21日 09:12""",
        'expect': {'amount': 59.0, 'time': datetime(2024, 5, 21, 9, 12), 'category': '购物'},
    },
    {
        'name': '滴滴出行',
        'text': """滴滴出行
-23.60
快车行程
支付成功
支付时间 2024-05-20 18:42
支付方式 微信支付""",
        'expect': {'amount': 23.6, 'merchant': '滴滴出行',
                   'time': datetime(2024, 5, 20, 18, 42), 'category': '交通'},
    },
]


def main():
    failed = 0
    for s in SAMPLES:
        got = parse(s['text'])
        print(f"\n── {s['name']}")
        print(f"   金额 {got['amount']}  商户 {got['merchant']}  "
              f"时间 {got['time']}  分类 {got['category']}  单号 {got['order_no']}")
        for k, v in s['expect'].items():
            ok = got[k] == v
            if not ok:
                failed += 1
            print(f"   {'✓' if ok else '✗'} {k}: 期望 {v} / 实际 {got[k]}")
    print('\n' + ('全部通过 ✅' if failed == 0 else f'失败 {failed} 项 ❌'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
