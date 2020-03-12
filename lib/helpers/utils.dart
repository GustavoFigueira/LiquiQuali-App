import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as img;

class ImageHelper {
  static Future<img.Image> getImage(String imagePath) async {
    final imageFile = File(imagePath);
    return img.decodeImage(imageFile.readAsBytesSync());
  }

  static Future<String> saveImage(img.Image newImage, String imagePath) async {
    var newFile = File(imagePath)
      ..createSync(recursive: true)
      ..writeAsBytes(img.encodePng(newImage));

    return newFile.path;
  }
}
