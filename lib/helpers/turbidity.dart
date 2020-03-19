import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:image/image.dart' as img;

class Turbidity {
  static double getRemoteSensingReflectance(img.Image image, double exposureTime, double isoSpeed, int sampleSize) {
    var rrs = 0.0;

    var waterRadiance = 0.0;
    var skyRadiance = 1;
    var cardRadiance = 0.18;

    waterRadiance = getRelativeRadiance(image, exposureTime, isoSpeed, sampleSize);

    // Remote Sensing Reflectance Formula
    rrs = (waterRadiance - (0.028 * skyRadiance)) / (pi / 0.18) * cardRadiance;
    //rrs = waterRadiance;

    return rrs;
  }

  static double getRelativeRadiance(img.Image image, double exposureTime, double isoSpeed, int sampleSize) {
    var radiance = 0.0;

    var lightSpeed = exposureTime * isoSpeed;

    if (lightSpeed == 0) lightSpeed = 1;

    var width = image.width;
    var height = image.height;
    var indeX = 0;
    var indexY = 0;

    // Utiliza apenas o quadrado central da amostra.
    // Caso seja 0, utiliza a imagem completa.
    if (sampleSize > 0) {
      width = sampleSize * 2;
      height = sampleSize * 2;
      indeX = sampleSize;
      indexY = sampleSize;
    }

    for (indeX = 0; indeX < width; indeX++) {
      for (indexY = 0; indexY < height; indexY++) {

        var pixel = image.getPixelSafe(indeX, indexY);
        var pixelColor = Color(pixel);

        // Relative Radiance Formula 1
        radiance += (pixelColor.red / lightSpeed);

        // Relative Radiance Formula 2
        //radiance += ((0.2126 * pixelColor.red) + (0.7152 * pixelColor.green) + (0.0722 * pixelColor.blue)) / lightSpeed;
      }
    }

    radiance = radiance / (image.width * image.height);

    return radiance;
  }

  static double getTurbidity(img.Image image,
      {double exposureTime = 0, double isoSpeed = 1, int sampleSize = 0}) {
    double turbidity = 0;

    // Remote Sensing Reflectance
    double rrs = 0;

    rrs = getRemoteSensingReflectance(image, exposureTime, isoSpeed, sampleSize);

    // Turbidity Formula
    //turbidity = (22.57 * rrs) / (0.044 - rrs);
    turbidity = (27.7 * rrs) / (0.05 - rrs);
    
    return turbidity.abs();
  }

  static String getNTURange(double ntu) {
    var range = "";

    if (ntu <= 20) {
      range = "[0±20] NTU";
    } else if (ntu > 20 && ntu <= 40) {
      range = "[20±40] NTU";
    } else if (ntu > 40 && ntu <= 60) {
      range = "[40±60] NTU";
    } else if (ntu > 60 && ntu <= 80) {
      range = "[60±80] NTU";
    } else if (ntu > 80) {
      range = "[80±200] NTU";
    }

    return range;
  }
}
