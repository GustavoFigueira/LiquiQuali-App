import 'package:flutter/material.dart';

class Utils {
  static void logError(String code, String message) =>
      print('Error: $code\nError Message: $message');

  static void showInSnackBar(
      GlobalKey<ScaffoldState> _scaffoldKey, String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }
}
