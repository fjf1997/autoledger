import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局设置（变更会通知 UI）
class SettingsStore extends ChangeNotifier {
  static const _kEngine = 'ocr_engine';
  static const _kEndpoint = 'ocr_endpoint';
  static const _kApiKey = 'ocr_api_key';
  static const _kModel = 'ocr_model';
  static const _kAutoSave = 'auto_save';
  static const _kListenNotification = 'listen_notification';
  static const _kMinConfidence = 'min_confidence';

  String _engineId = 'platform';
  String _endpoint = '';
  String _apiKey = '';
  String _model = 'gpt-4o-mini';
  bool _autoSave = true;
  bool _listenNotification = false;
  double _minConfidence = 0.6;

  String get engineId => _engineId;
  String get endpoint => _endpoint;
  String get apiKey => _apiKey;
  String get model => _model;
  bool get autoSave => _autoSave;
  bool get listenNotification => _listenNotification;
  double get minConfidence => _minConfidence;

  static Future<SettingsStore> load() async {
    final s = SettingsStore();
    final sp = await SharedPreferences.getInstance();
    s._engineId = sp.getString(_kEngine) ?? 'platform';
    s._endpoint = sp.getString(_kEndpoint) ?? '';
    s._apiKey = sp.getString(_kApiKey) ?? '';
    s._model = sp.getString(_kModel) ?? 'gpt-4o-mini';
    s._autoSave = sp.getBool(_kAutoSave) ?? true;
    s._listenNotification = sp.getBool(_kListenNotification) ?? false;
    s._minConfidence = sp.getDouble(_kMinConfidence) ?? 0.6;
    return s;
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kEngine, _engineId);
    await sp.setString(_kEndpoint, _endpoint);
    await sp.setString(_kApiKey, _apiKey);
    await sp.setString(_kModel, _model);
    await sp.setBool(_kAutoSave, _autoSave);
    await sp.setBool(_kListenNotification, _listenNotification);
    await sp.setDouble(_kMinConfidence, _minConfidence);
  }

  Future<void> setEngine(String id) async {
    _engineId = id;
    await _save();
    notifyListeners();
  }

  Future<void> setRemoteConfig({
    required String endpoint,
    required String apiKey,
    required String model,
  }) async {
    _endpoint = endpoint.trim();
    _apiKey = apiKey.trim();
    _model = model.trim().isEmpty ? 'gpt-4o-mini' : model.trim();
    await _save();
    notifyListeners();
  }

  Future<void> setAutoSave(bool v) async {
    _autoSave = v;
    await _save();
    notifyListeners();
  }

  Future<void> setListenNotification(bool v) async {
    _listenNotification = v;
    await _save();
    notifyListeners();
  }

  Future<void> setMinConfidence(double v) async {
    _minConfidence = v;
    await _save();
    notifyListeners();
  }
}
