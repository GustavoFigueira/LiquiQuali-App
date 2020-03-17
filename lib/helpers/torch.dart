import 'dart:async';

import 'package:flutter/services.dart';

class Torch {
  static const MethodChannel _channel = const MethodChannel('fflashlight');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> get hasFlashlight async {
    return await _channel.invokeMethod("hasFlashlight");
  }

  static Future<void> turnOn() async {
    return await _channel.invokeMethod('on');
  }

  static Future<void> turnOff() async {
    return await _channel.invokeMethod('on');
  }

  static Future<void> enable(bool state) async {
    return await _channel.invokeMethod('enable', {'state': state});
  }

  static Future flash(Duration duration) => turnOn()
      .whenComplete(() => new Future.delayed(duration, () => turnOff()));
}
