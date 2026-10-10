import 'dart:io';

/// OCR 引擎统一抽象。
///
/// 想接自己的识别服务，实现本接口并在 [OcrRegistry] 里注册即可，
/// 上层 UI 与解析逻辑完全不用改。
/// 识别失败统一异常
class OcrException implements Exception {
  final String message;
  OcrException(this.message);

  @override
  String toString() => message;
}

abstract class OcrProvider {
  /// 唯一标识，存进设置
  String get id;

  /// 展示名
  String get name;

  /// 是否需要联网 / 配置
  bool get requiresConfig;

  Future<bool> isAvailable();

  /// 输入图片路径，返回识别出的纯文本（多行）
  Future<String> recognize(File imageFile);
}

/// 所有可用引擎的注册表
class OcrRegistry {
  final Map<String, OcrProvider> _map = {};

  OcrRegistry(Iterable<OcrProvider> providers) {
    for (final p in providers) {
      _map[p.id] = p;
    }
  }

  Iterable<OcrProvider> get all => _map.values;

  OcrProvider? byId(String id) => _map[id];

  OcrProvider getOrDefault(String id) =>
      _map[id] ?? _map.values.firstWhere((p) => !p.requiresConfig);
}
