import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:LiquiQuali/helpers/image_processing.dart';
import 'package:LiquiQuali/helpers/orientation_utils.dart';
import 'package:LiquiQuali/helpers/turbidity.dart';
import 'package:LiquiQuali/helpers/utils.dart';
import 'package:aeyrium_sensor/aeyrium_sensor.dart';
import 'package:animator/animator.dart';
import 'package:camerawesome/models/orientations.dart';
import 'package:exif/exif.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as imgUtils;

import 'package:path_provider/path_provider.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:permission_handler/permission_handler.dart';

import 'preview_page.dart';
import 'widgets/camera_buttons.dart';
import 'widgets/main_menu.dart';
import 'widgets/take_photo_button.dart';

class MainCamera extends StatefulWidget {
  final bool randomPhotoName;
  final Permission permission;

  MainCamera({this.randomPhotoName = true, this.permission});

  @override
  _MainCameraState createState() => _MainCameraState();
}

class _MainCameraState extends State<MainCamera> with TickerProviderStateMixin {
  String originalImagePath;
  String flashImagePath;
  bool _hasFlash = false;
  bool isProcessing = false;
  int pitch = 0;
  double scannerSize = 200;
  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final Permission _permission = Permission.camera;
  PermissionStatus _permissionStatus = PermissionStatus.undetermined;

  double bestSizeRatio;

  String _lastPhotoPath;

  bool focus = false;

  bool fullscreen = true;

  ValueNotifier<CameraFlashes> switchFlash = ValueNotifier(CameraFlashes.NONE);

  ValueNotifier<Size> photoSize = ValueNotifier(null);

  PictureController _pictureController = new PictureController();

  List<Size> availableSizes;

  AnimationController _iconsAnimationController;

  AnimationController _previewAnimationController;

  Animation<Offset> _previewAnimation;

  bool animationPlaying = false;

  Timer _previewDismissTimer;

  ValueNotifier<CameraOrientations> _orientation =
      ValueNotifier(CameraOrientations.PORTRAIT_UP);

  @override
  void initState() {
    super.initState();
    _listenForPermissionStatus();
    requestPermission(_permission);
    setLastAnalysis();

    // Pitch (rotação no Eixo X)
    AeyriumSensor.sensorEvents.listen((SensorEvent event) {
      var radians = event.pitch;
      var degrees = (180 / pi) * radians;
      this.setState(() {
        pitch = degrees.round().abs();
      });
    });
  }

  void _listenForPermissionStatus() async {
    final status = await _permission.status;
    setState(() => _permissionStatus = status);
  }

  Future<void> requestPermission(Permission permission) async {
    final status = await permission.request();

    setState(() {
      print(status);
      _permissionStatus = status;
      print(_permissionStatus);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _iconsAnimationController.dispose();
    _previewAnimationController.dispose();
    photoSize.dispose();
    super.dispose();
  }

  Future<void> setLastAnalysis() async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/LiquiQuali';

    // Caso queira deletar
    //extDir.deleteSync(recursive: true);
    // TODO: ordernar pela data de modificação
    if (Directory(dirPath).existsSync()) {
      var filesList = Directory(dirPath).listSync();
      setState(() {
        originalImagePath = filesList.last?.path ?? "";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Alignment alignment;
    bool mirror;
    switch (_orientation.value) {
      case CameraOrientations.PORTRAIT_UP:
      case CameraOrientations.PORTRAIT_DOWN:
        alignment = _orientation.value == CameraOrientations.PORTRAIT_UP
            ? Alignment.bottomLeft
            : Alignment.topLeft;
        mirror = _orientation.value == CameraOrientations.PORTRAIT_DOWN;
        break;
      case CameraOrientations.LANDSCAPE_LEFT:
      case CameraOrientations.LANDSCAPE_RIGHT:
        alignment = Alignment.topLeft;
        mirror = _orientation.value == CameraOrientations.LANDSCAPE_LEFT;
        break;
    }

    return Scaffold(
        key: _scaffoldKey,
        drawer:
            isProcessing ? SizedBox.shrink() : Drawer(child: MainMenuDrawer()),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            buildFullscreenCamera(),
            isProcessing
                ? _processingWidget()
                : Positioned.fill(
                    child: Align(
                    alignment: Alignment.center,
                    child: Stack(
                      children: <Widget>[
                        Container(
                            width: scannerSize,
                            height: scannerSize,
                            decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(
                                    color: Colors.greenAccent, width: 2))),
                        Container(
                          alignment: Alignment.center,
                          width: scannerSize,
                          height: scannerSize,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Text("${pitch.toString()}°",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: pitch == 45
                                          ? Colors.green
                                          : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 48)),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  text: 'Mantenha seu dispositivo inclinado à ',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                  children: <TextSpan>[
                                    TextSpan(
                                        text: '45°',
                                        style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    TextSpan(
                                        text: '.',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18))
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  )),
            _customAppBar(),
            _cameraActions()
          ],
        ));
  }

  Widget _takePhotoButton() {
    return isProcessing
        ? SizedBox.shrink()
        : Positioned(
            bottom: 0,
            child: Container(
                margin: EdgeInsets.symmetric(vertical: 30),
                child: RaisedButton.icon(
                  elevation: 4.0,
                  icon: Icon(Icons.photo_camera, color: Colors.white),
                  color: Colors.black54,
                  label: Text("Analisar",
                      style: TextStyle(color: Colors.white, fontSize: 16.0)),
                  onPressed: onTakePictureButtonPressed,
                )),
          );
  }

  Widget _customAppBar() {
    return isProcessing
        ? SizedBox.shrink()
        : AppBar(
            centerTitle: true,
            elevation: 0,
            title: Text("LiquiQuali",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: <Shadow>[
                    Shadow(
                        offset: Offset(0, 0.3),
                        blurRadius: 5,
                        color: Colors.black54)
                  ],
                )),
            backgroundColor: Colors.transparent);
  }

  Widget _processingWidget() {
    return Positioned.fill(
        child: Align(
            alignment: Alignment.center,
            child: Stack(
              children: <Widget>[
                Container(
                    width: scannerSize,
                    height: scannerSize,
                    child: Align(
                        alignment: Alignment.center,
                        child: Text('*ANALISANDO*\n Não mova seu dispositivo.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18))),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        border:
                            Border.all(color: Colors.greenAccent, width: 2))),
                Animator(
                  tween: Tween<double>(
                      begin: 0, end: MediaQuery.of(context).size.height / 2.6),
                  duration: Duration(seconds: 1),
                  cycles: 0,
                  builder: (anim) => Positioned(
                    top: anim.value,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        height: 4,
                        width: MediaQuery.of(context).size.width,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
                ),
                Positioned(
                    left: 0,
                    bottom: 0,
                    child: RaisedButton.icon(
                      elevation: 4.0,
                      icon: Icon(Icons.photo_camera, color: Colors.black),
                      color: Colors.white,
                      label: Text("Cancelar",
                          style:
                              TextStyle(color: Colors.black, fontSize: 16.0)),
                      onPressed: () {
                        setProcessingState(false);
                      },
                    ))
              ],
            )));
  }

  Widget _cameraActions() {
    return Positioned(
        bottom: 0,
        left: 0,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[_takePhotoButton(), _thumbnailWidget()],
        ));
  }

  Widget _thumbnailWidget() {
    return isProcessing
        ? SizedBox.shrink()
        : Positioned(
            bottom: 0,
            right: 0,
            child: originalImagePath == null
                ? SizedBox.shrink()
                : GestureDetector(
                    child: Container(
                      margin:
                          EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      height: 60,
                      width: 40,
                      color: Colors.black54,
                      child: Image(
                        image: FileImage(File(originalImagePath)),
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return PreviewPage(originalImagePath);
                    })),
                  ),
          );
  }

  void onTakePictureButtonPressed() async {
    try {
      setProcessingState(true);

      final Directory extDir = await getApplicationDocumentsDirectory();
      var testDir =
          await Directory('${extDir.path}/LiquiQuali').create(recursive: true);
      final String filePath =
          '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      await _pictureController.takePicture(filePath);

      // Vibra o celular
      HapticFeedback.mediumImpact();

      setState(() {
        originalImagePath = filePath;
      });

      setState(() {
        originalImagePath = filePath;
      });
      if (filePath == null) return;

      // Analisa a turbidez
      var originalImage = await ImageHelper.getImage(filePath);
      var exifTags = await readExifFromBytes(File(filePath).readAsBytesSync());
      var exposureTime = ImageHelper.getExposureTime(exifTags);
      var iso = ImageHelper.getIso(exifTags);

      // Ativa o flash
      final String _flashImagepath =
          '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}_f.jpg';

      setState(() {
        switchFlash = ValueNotifier(CameraFlashes.ON);
      });

      await _pictureController.takePicture(_flashImagepath);

      setState(() {
        flashImagePath = _flashImagepath;
      });

      if (_flashImagepath == null) return;

      var flashImage = await ImageHelper.getImage(_flashImagepath);

      var finalImage =
          ImageHelper.getImageSubtraction(originalImage, flashImage);

      var clarityAmount = ImageHelper.imageClarityAmount(finalImage);

      await ImageHelper.saveImage(finalImage, flashImagePath)
          .then((String newPath) async {
        setState(() {
          originalImagePath = newPath;
        });
      });

      // TODO: trocar pela quantização de pixels pretos
      var turbidity = Turbidity.getTurbidity(finalImage,
          exposureTime: exposureTime,
          isoSpeed: iso,
          sampleSize: scannerSize.round());

      // Multiplica a turbidez pelo coeficiente de pixels escuros
      if (clarityAmount == 0) {
        turbidity = turbidity * 1000;
      } else {
        turbidity = (turbidity / clarityAmount) * 1000;
      }

      // Apresenta a turbidez final
      Utils.showInSnackBar(
          _scaffoldKey, "$turbidity - ${Turbidity.getNTURange(turbidity)}");

      setProcessingState(false);
    } on Exception catch (e) {
      setProcessingState(false);
      Utils.showInSnackBar(_scaffoldKey, e.toString());
    }
  }

  void setProcessingState(bool value) {
    setState(() {
      isProcessing = value;
    });
  }

  Widget _buildPreviewPicture({bool reverseImage = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(
          Radius.circular(15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            offset: Offset(2, 2),
            blurRadius: 25,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13.0),
          child: _lastPhotoPath != null
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(reverseImage ? pi : 0.0),
                  child: Image.file(
                    new File(_lastPhotoPath),
                    width: OrientationUtils.isOnPortraitMode(_orientation.value)
                        ? 128
                        : 256,
                  ),
                )
              : Container(
                  width: OrientationUtils.isOnPortraitMode(_orientation.value)
                      ? 128
                      : 256,
                  height: 228,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.photo,
                      color: Colors.white,
                    ),
                  ),
                ), // TODO: Placeholder here
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (switchFlash.value) {
      case CameraFlashes.NONE:
        return Icons.flash_off;
      case CameraFlashes.ON:
        return Icons.flash_on;
      case CameraFlashes.AUTO:
        return Icons.flash_auto;
      case CameraFlashes.ALWAYS:
        return Icons.highlight;
      default:
        return Icons.flash_off;
    }
  }

  _onOrientationChange(CameraOrientations newOrientation) {
    _orientation.value = newOrientation;
    if (_previewDismissTimer != null) {
      _previewDismissTimer.cancel();
    }
  }

  _onPermissionsResult(bool granted) {
    if (!granted) {
      AlertDialog alert = AlertDialog(
        title: Text('Error'),
        content: Text(
            'It seems you doesn\'t authorized some permissions. Please check on your settings and try again.'),
        actions: [
          FlatButton(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );

      // show the dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return alert;
        },
      );
    } else {
      setState(() {});
      print("granted");
    }
  }

  // /// this is just to preview images from stream
  // /// This use a bufferTime to take an image each 1500 ms
  // /// you cannot show every frame as flutter cannot draw them fast enough
  // /// [THIS IS JUST FOR DEMO PURPOSE]
  // Widget _buildPreviewStream() {
  //   if(previewStream == null)
  //     return Container();
  //   return Positioned(
  //     left: 32,
  //     bottom: 120,
  //     child: StreamBuilder(
  //       stream: previewStream.bufferTime(Duration(milliseconds: 1500)),
  //       builder: (context, snapshot) {
  //         if(!snapshot.hasData && snapshot.data.isNotEmpty)
  //           return Container();
  //         List<Uint8List> data = snapshot.data;
  //         print("...${DateTime.now()} new image received... ${data.last.lengthInBytes} bytes");
  //         return Image.memory(
  //           data.last,
  //           width: 120,
  //         );
  //       },
  //     )
  //   );
  // }

  Widget buildFullscreenCamera() {
    return Positioned(
        top: 0,
        left: 0,
        bottom: 0,
        right: 0,
        child: Center(
          child: CameraAwesome(
            onPermissionsResult: _onPermissionsResult,
            selectDefaultSize: (availableSizes) {
              this.availableSizes = availableSizes;

              var size = Size(800, 480);

              return availableSizes.contains(size)
                  ? size
                  : availableSizes[(availableSizes.length - 1 / 2).toInt()];
            },
            photoSize: photoSize,
            sensor: ValueNotifier(Sensors.BACK),
            switchFlashMode: switchFlash,
            onOrientationChanged: _onOrientationChange,
            onCameraStarted: () {
              // camera started here -- do your after start stuff
            },
          ),
        ));
  }
}
