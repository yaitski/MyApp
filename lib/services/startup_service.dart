import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/startup_data.dart';

class StartupService {
  final String baseUrl = 'https://appmyid.open4u.ru';
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Главный метод - собирает и отправляет данные
  Future<bool> sendStartupData(BuildContext context) async {
    try {
      // 1. Собираем данные
      final data = await _collectData(context);

      // 2. Отправляем на сервер
      final response = await http.post(
        Uri.parse('$baseUrl'), // путь уточните у бэкенда
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data.toJson()),
      );

      // 3. Сохраняем статус отправки
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('startup_sent', true);
        print('✅ Данные отправлены успешно');
        return true;
      } else {
        print('❌ Ошибка: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Ошибка отправки: $e');
      return false;
    }
  }

  // Сбор всех данных
  Future<StartupData> _collectData(BuildContext context) async {
    final deviceId = await _getOrCreateDeviceId();
    final ipAddress = await _getIpAddress();
    final screenInfo = _getScreenInfo(context);
    final platform = Platform.operatingSystem;
    final osVersion = await _getOsVersion();
    final deviceLanguage = _getDeviceLanguage();
    final appVersion = await _getAppVersion();

    return StartupData(
      deviceId: deviceId,
      ipAddress: ipAddress,
      screenWidth: screenInfo['width'] ?? 0,
      screenHeight: screenInfo['height'] ?? 0,
      platform: platform,
      osVersion: osVersion,
      deviceLanguage: deviceLanguage,
      appVersion: appVersion,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  // Генерация или получение сохраненного device_id
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  // Получение публичного IP
  Future<String?> _getIpAddress() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.ipify.org'),
        headers: {'Cache-Control': 'no-cache'},
      );
      return response.statusCode == 200 ? response.body.trim() : null;
    } catch (e) {
      return null;
    }
  }

  // Получение размеров экрана
  Map<String, double> _getScreenInfo(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return {
      'width': size.width,
      'height': size.height,
    };
  }

  // Получение версии приложения
  Future<String> _getAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } catch (e) {
      return '1.0.0+1';
    }
  }

  Future<String> _getOsVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.version.release; // Например: "14" или "13.0"
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.systemVersion; // Например: "17.4.1"
      } else {
        return 'unknown';
      }
    } catch (e) {
      print('❌ Ошибка получения версии ОС: $e');
      return 'unknown';
    }
  }

  String _getDeviceLanguage() {
    try {
      final locale = WidgetsBinding.instance.window.locale;
      final languageCode = locale.languageCode;
      final countryCode = locale.countryCode;

      return countryCode != null
          ? '$languageCode-$countryCode'
          : languageCode;

    } catch (e) {
      print('❌ Ошибка получения языка: $e');
      return 'unknown';
    }
  }
}