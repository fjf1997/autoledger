import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'ocr_provider.dart';

/// 预留的多模态大模型 OCR：把图片 base64 发给一个 OpenAI 兼容的
/// /v1/chat/completions 视觉接口，让它把截图里的文字原样输出。
///
/// 留好接口但默认不启用：在「设置」里填 Endpoint / Key / 模型即可切换，
/// 也可以换成你自己的后端（只要返回 {choices[0].message.content} 文本）。
class RemoteVisionOcrProvider implements OcrProvider {
  final String endpoint; // 例如 https://api.openai.com/v1/chat/completions
  final String apiKey;
  final String model; // 例如 gpt-4o-mini / qwen-vl-max / hunyuan-vision

  RemoteVisionOcrProvider({
    required this.endpoint,
    required this.apiKey,
    this.model = 'gpt-4o-mini',
  });

  @override
  String get id => 'remote_vision';

  @override
  String get name => '大模型识别（联网）';

  @override
  bool get requiresConfig => true;

  bool get configured => endpoint.isNotEmpty && apiKey.isNotEmpty;

  @override
  Future<bool> isAvailable() async => configured;

  static const _prompt = '请把这张支付账单截图里的文字全部逐行提取出来，'
      '保留原有顺序与标点，不要翻译、不要总结、不要解释，只输出原文。';

  @override
  Future<String> recognize(File imageFile) async {
    if (!configured) {
      throw OcrException('未配置大模型识别：请先填写 Endpoint 与 API Key');
    }
    final bytes = await imageFile.readAsBytes();
    final b64 = base64Encode(bytes);
    final uri = Uri.parse(endpoint);

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': _prompt},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/jpeg;base64,$b64'},
            },
          ],
        }
      ],
      'temperature': 0,
      'max_tokens': 1500,
    });

    final resp = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 45));

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw OcrException('识别服务返回 ${resp.statusCode}：${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw OcrException('识别服务未返回内容');
    }
    final msg = choices[0]['message'] as Map<String, dynamic>?;
    final content = msg?['content'];
    if (content is String) return content;
    if (content is List) {
      return content
          .map((e) => (e is Map ? (e['text'] ?? '') : '').toString())
          .join('\n');
    }
    throw OcrException('无法解析识别服务返回');
  }
}
