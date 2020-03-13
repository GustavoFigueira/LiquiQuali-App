import 'dart:async';
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;

class ImageHelper {
  static Future<img.Image> getImage(String imagePath) async {
    final imageFile = File(imagePath);
    return img.decodeJpg(imageFile.readAsBytesSync());
  }

  static Future<String> saveImage(img.Image newImage, String imagePath) async {
    var newFile = File(imagePath)
      ..createSync(recursive: true)
      ..writeAsBytes(img.encodePng(newImage));

    return newFile.path;
  }

  static double getExposureTime(Map<String, IfdTag> imgTags) {
    double exposureTime = 0;

    if (imgTags.containsKey('EXIF ExposureTime')) {
       Ratio exposure = imgTags['EXIF ExposureTime']?.values[0];

       exposureTime = exposure.denominator != 0? exposure.numerator / exposure.denominator : 0;
    }

    return exposureTime;
  }

  static double getIso(Map<String, IfdTag> imgTags) {
    double iso = 0;

    if (imgTags.containsKey('EXIF ISOSpeedRatings')) {
      iso = double.tryParse(imgTags['EXIF ISOSpeedRatings']?.values[0].toString());
    }

    return iso;
  }

  static dynamic extractExifData(Map<String, IfdTag> tags, String targetTag) {
    var exifValue = tags[targetTag]?.values[0];

    return exifValue;
  }
}
