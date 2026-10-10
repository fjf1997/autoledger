import 'dart:io';

import 'package:flutter/services.dart';

import 'ocr_provider.dart';

/// 端侧 OCR：通过 MethodChannel 调用原生能力
/// - Android：ML Kit Text Recognition（中文）
/// - iOS：Vision VNRecognizeTextRequest
///
/// 不联网、不花钱，是默认引擎。
class PlatformOcrProvider implements OcrProvider {
  static const _channel = MethodChannel('auto_ledger/ocr');

  @override
  String get id => 'platform';

  @override
  String get name => '端侧识别（离线）';

  @override
  bool get requiresConfig => false;

  @override
  Future<bool> isAvailable() async {
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable');
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> recognize(File imageFile) async {
    try {
      final text = await _channel.invokeMethod<String>('recognizeText', {
        'path': imageFile.path,
      });
      return text ?? '';
    } on MissingPluginException {
      throw OcrException('端侧识别未接入（原生通道缺失）');
    } on PlatformException catch (e) {
      throw OcrException('端侧识别失败：${e.message ?? e.code}');
    }
  }
}
