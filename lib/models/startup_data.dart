import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StartupData {
  final String deviceId;
  final String? ipAddress;
  final double screenWidth;
  final double screenHeight;
  final String platform;
  final String osVersion;
  final String deviceLanguage;
  final String appVersion;
  final String timestamp;

  StartupData({
    required this.deviceId,
    this.ipAddress,
    required this.screenWidth,
    required this.screenHeight,
    required this.platform,
    required this.osVersion,
    required this.deviceLanguage,
    required this.appVersion,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'ip_address': ipAddress,
    'screen_width': screenWidth,
    'screen_height': screenHeight,
    'platform': platform,
    'os_version': osVersion,
    'device_language': deviceLanguage,
    'app_version': appVersion,
    'timestamp': timestamp,
  };
}