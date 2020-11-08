import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/painting.dart';

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

      exposureTime = exposure.denominator != 0
          ? exposure.numerator / exposure.denominator
          : 0;
    }

    return exposureTime;
  }

  static double getIso(Map<String, IfdTag> imgTags) {
    double iso = 0;

    if (imgTags.containsKey('EXIF ISOSpeedRatings')) {
      iso = double.tryParse(
          imgTags['EXIF ISOSpeedRatings']?.values[0].toString());
    }

    return iso;
  }

  static dynamic extractExifData(Map<String, IfdTag> tags, String targetTag) {
    var exifValue = tags[targetTag]?.values[0];

    return exifValue;
  }

  static img.Image getImageSubtraction(
      img.Image originalImage, img.Image flashImage) {
    int _width = min(originalImage.width, flashImage.width);
    int _height = min(originalImage.height, flashImage.height);

    List<List<int>> differences =
        new List.generate(_width, (_) => new List(_height));

    for (int x = 0; x < _width; x++) {
      for (int y = 0; y < _height; y++) {
        Color color1 = Color(originalImage.getPixelSafe(x, y));
        Color color2 = Color(flashImage.getPixelSafe(x, y));

        var pixelSubtraction = Color.fromARGB(
            255,
            (color2.red - color1.red).abs(),
            (color2.green - color1.green).abs(),
            (color2.blue - color1.blue).abs());

        differences[x][y] = pixelSubtraction.value;
      }
    }

    // Gera a imagem final
    img.Image finalImage = new img.Image(_width, _height);
    for (int x = 0; x < _width; x++) {
      for (int y = 0; y < _height; y++) {
        var newColor = differences[x][y];
        finalImage.setPixelSafe(x, y, newColor);
      }
    }

    return finalImage;
  }

  static double imageClarityAmount(img.Image subtractionImage) {
    var darksAmountPercentage = 0.0;
    var darksAmount = 0.0;
    var width = subtractionImage.width;
    var height = subtractionImage.height;

    for (var x = 0; x < subtractionImage.width; x++) {
      for (var y = 0; y < subtractionImage.height; y++) {
        var luminance = Color(subtractionImage.getPixelSafe(x, y)).computeLuminance();
        if (luminance < 0.7) {
          darksAmount++;
        }
      }
    }

    var pixelsTotal = width * height;
    darksAmountPercentage = (darksAmount * 100) / pixelsTotal;
    
    return darksAmountPercentage;
  }
}
