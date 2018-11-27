import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ImageDimensions {
  final int width;
  final int height;

  ImageDimensions({this.width, this.height})
      : assert(width != null),
        assert(height != null);

  @override
  int get hashCode => hashValues(width, height);

  @override
  bool operator ==(other) {
    return other is ImageDimensions &&
        other.width == width &&
        other.height == height;
  }

  @override
  String toString() {
    return '$runtimeType(width: $width, height: $height)';
  }
}

class CropSquareImage {
  static const MethodChannel _channel =
      const MethodChannel('crop_square_image');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<String> get currentTemperature async {
    final String temperature =
        await _channel.invokeMethod('getCurrentTemperature');
    return temperature;
  }

  static Future<bool> requestPermissions() {
    return _channel
        .invokeMethod('requestPermissions')
        .then<bool>((result) => result);
  }

  static Future<ImageDimensions> getImageDimensions({File file}) async {
    assert(file != null);
    final result =
    await _channel.invokeMethod('getImageDimensions', {'path': file.path});
    return ImageDimensions(
      width: result['width'],
      height: result['height'],
    );
  }

  static Future<File> cropImage({
    File file,
    Rect area,
    double scale,
  }) {
    assert(file != null);
    assert(area != null);
    return _channel.invokeMethod('cropImage', {
      'path': file.path,
      'left': area.left,
      'top': area.top,
      'right': area.right,
      'bottom': area.bottom,
      'scale': scale ?? 1.0,
    }).then<File>((result) => File(result));
  }

  static Future<File> cropImage2(
      String fileName, int originX, int originY, int width, int height) async {
    var file = await _channel.invokeMethod("cropImage2", {
      'file': fileName,
      'originX': originX,
      'originY': originY,
      'width': width,
      'height': height
    });
    return new File(file);
  }

  static Future<File> scaleImage2(String fileName,
      {int percentage = 70,
        int quality = 70,
        int targetWidth = 0,
        int targetHeight = 0}) async {
    var file = await _channel.invokeMethod("scaleImage2", {
      'file': fileName,
      'quality': quality,
      'percentage': percentage,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight
    });

    return new File(file);
  }


}
