import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as img;

class ImageHelper {
  static Future<img.Image> getImage(String imagePath) async {
    final imageFile = File(imagePath);
    return img.decodeImage(imageFile.readAsBytesSync());
  }
}
