import 'dart:math' as math;

/// 记账分类：颜色 + 图标 + 关键词
class Category {
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final List<String> keywords;

  const Category(this.name, this.colorValue, this.iconCodePoint,
      {this.keywords = const []});

  // —— 预置分类 ——
  static const food = Category('餐饮', 0xFFEF6C00, 0xe532, keywords: [
    '美团', '饿了么', '外卖', '星巴克', '瑞幸', 'luckin', '麦当劳', '肯德基', 'kfc',
    '海底捞', '喜茶', '奈雪', '蜜雪冰城', '茶百道', '古茗', '霸王茶姬', '咖啡', '奶茶',
    '餐饮', '食品', '餐厅', '饭店', '食堂', '火锅', '烧烤', '小吃', '面馆', '酒楼',
    '糕点', '面包', '生鲜', '菜市', 'food',
  ]);
  static const transport = Category('交通', 0xFF1565C0, 0xe531, keywords: [
    '滴滴', '高德', '出租', '网约车', '地铁', '公交', '高铁', '12306', '火车', '机票',
    '航空', '加油', '中石化', '中石油', '停车', 'ETC', '共享单车', '哈啰', '青桔',
    '摩拜', 'ofo', '打车', '出行', '铁路', '客运',
  ]);
  static const shopping = Category('购物', 0xFFC2185B, 0xe54c, keywords: [
    '淘宝', '天猫', '京东', '拼多多', '唯品会', '闲鱼', '苏宁', '超市', '沃尔玛',
    '永辉', '盒马', '便利店', '商城', '优衣库', '小米', '苹果', 'apple', '华为',
    '服饰', '鞋', '数码', '家电', '百货', 'shopping',
  ]);
  static const entertainment = Category('娱乐', 0xFF7B1FA2, 0xe40c, keywords: [
    '电影', '影院', '万达影', 'ktv', '唱吧', '游戏', 'steam', '腾讯视频', '爱奇艺',
    '优酷', '芒果tv', 'bilibili', 'b站', '网易云', 'qq音乐', '会员', '充值', '健身',
    '游泳', '旅游', '门票', '景区', '酒店', '民宿', '携程', '去哪儿',
  ]);
  static const housing = Category('居住', 0xFF00695C, 0xe1ff, keywords: [
    '房租', '租金', '物业', '水费', '电费', '燃气', '煤气', '宽带', '水电', '供暖',
    '中介', '公寓', '保洁', '家政',
  ]);
  static const medical = Category('医疗', 0xFFD32F2F, 0xe3f3, keywords: [
    '医院', '药房', '药店', '大药房', '诊所', '体检', '挂号', '门诊', '口腔', '眼科',
    '医保', '药品',
  ]);
  static const education = Category('教育', 0xFF4527A0, 0xe530, keywords: [
    '学校', '学费', '书店', '课程', '培训', '考试', '考研', '图书', '教材', '网课',
    '教育', '学习',
  ]);
  static const telecom = Category('通讯', 0xFF00838F, 0xe554, keywords: [
    '话费', '流量', '中国移动', '中国联通', '中国电信', '充值中心', '短信', '宽带费',
  ]);
  static const daily = Category('日用', 0xFF558B2F, 0xe547, keywords: [
    '日用', '家居', '清洁', '洗护', '纸品', '文具', '便利店', '名创优品', '杂物',
  ]);
  static const transfer = Category('转账', 0xFF455A64, 0xe54f, keywords: [
    '转账', '收款', '红包', '亲属卡', '收款码', '付款码', '好友', '扫一扫', '面对面',
  ]);
  static const finance = Category('理财', 0xFFFF8F00, 0xe263, keywords: [
    '余额宝', '零钱通', '基金', '理财', '保险', '信用卡', '还款', '花呗', '借呗',
    '分期', '银行', '存款', '利息',
  ]);
  static const income = Category('收入', 0xFF2E7D32, 0xe525, keywords: [
    '工资', '薪水', '薪资', '报销', '退款', '退货', '收入', '转入', '收款', '奖金',
    '提成', '红包收入', '补贴', '兼职',
  ]);
  static const other = Category('其他', 0xFF78909C, 0xe5cd);

  static const List<Category> all = [
    food,
    transport,
    shopping,
    entertainment,
    housing,
    medical,
    education,
    telecom,
    daily,
    transfer,
    finance,
    income,
    other,
  ];

  static Category byName(String name) =>
      all.firstWhere((c) => c.name == name, orElse: () => other);

  static int colorOf(String name) => byName(name).colorValue;
  static int iconOf(String name) => byName(name).iconCodePoint;

  /// 关键词命中分类；文本应全部转小写后传入
  static Category match(String lowerText) {
    Category? best;
    var bestScore = 0;
    for (final c in all) {
      if (c == other) continue;
      var score = 0;
      for (final k in c.keywords) {
        if (lowerText.contains(k)) {
          // 命中越长越可信
          score += k.length;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best ?? other;
  }
}

/// 金额区间 → 用于图表展示时的辅助工具
class AmountUtil {
  static double round2(double v) => (v * 100).round() / 100;
  static double maxOf(Iterable<double> xs) =>
      xs.fold(0.0, (a, b) => math.max(a, b));
}
