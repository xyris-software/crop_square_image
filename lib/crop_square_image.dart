import 'dart:async';

import 'package:flutter/services.dart';

class CropSquareImage {
  static const MethodChannel _channel =
      const MethodChannel('crop_square_image');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> get currentTemperature async {
    final String temperature = await _channel.invokeMethod('getCurrentTemperature');
    return temperature;
  }
}
