import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class PermissionService {
  static Future<bool> requestPhotoPermission() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      // Android 13+ (API 33+)
      if (androidInfo.version.sdkInt >= 33) {
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      } else {
        // Legacy Android
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } else if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }
    return true;
  }

  static Future<PermissionStatus> getPhotoPermissionStatus() async {
    if (kIsWeb) return PermissionStatus.granted;

    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        return await Permission.photos.status;
      } else {
        return await Permission.storage.status;
      }
    } else if (Platform.isIOS) {
      return await Permission.photos.status;
    }
    return PermissionStatus.granted;
  }
}
