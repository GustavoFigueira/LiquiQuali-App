import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:aeyrium_sensor/aeyrium_sensor.dart';
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:animator/animator.dart';

import 'helpers/image_processing.dart';
import 'helpers/turbidity.dart';
import 'helpers/utils.dart';
import 'pages/preview_page.dart';
import 'pages/shared/main_menu.dart';

// TODO: fazer alerta a ser apresentando uma vez falandoq ue o flahs será ativado
// TODO: funncção de compartilhar imagem com textos da medição

class MainCamera extends StatefulWidget {
  @override
  _MainCameraState createState() {
    return _MainCameraState();
  }
}

IconData getCameraLensIcon(CameraLensDirection direction) {
  switch (direction) {
    case CameraLensDirection.back:
      return Icons.camera_rear;
    case CameraLensDirection.front:
      return Icons.camera_front;
    case CameraLensDirection.external:
      return Icons.camera;
  }
  throw ArgumentError('Direção da câmera desconhecida.');
}

class _MainCameraState extends State<MainCamera>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController _controller;
  CameraLensDirection currentCamera;
  String originalImagePath;
  String flashImagePath;
  bool _hasFlash = false;
  bool isProcessing = false;
  int pitch = 0;
  double scannerSize = 200;
  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
  final PermissionHandler _permissionHandler = PermissionHandler();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    requestPermissions(<PermissionGroup>[PermissionGroup.camera]).then((bool) {
      onNewCameraSelected(cameras[0]);
    });
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller != null) {
        onNewCameraSelected(_controller.description);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        drawer:
            isProcessing ? SizedBox.shrink() : Drawer(child: MainMenuDrawer()),
        body: Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: <Widget>[
                _cameraPreviewWidget(),
                _customAppBar(),
                _cameraActions(),
              ],
            )));
  }

  Future<void> deviceHasFlash() async {
    bool hasFlash = false;

    if (_controller != null) {
      hasFlash = await _controller.hasFlash;
    }

    setState(() {
      _hasFlash = hasFlash;
    });
  }

  Future<void> requestPermissions(List<PermissionGroup> permissions,
      {Function onPermissionDenied}) async {
    var result = await _permissionHandler.requestPermissions(permissions);
    for (PermissionGroup permission in permissions) {
      if (result[permission] != PermissionStatus.granted) {
        onPermissionDenied();
      }
    }
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
                    onPressed: () => onTakePictureButtonPressed())),
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
                )
              ],
            )));
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (_controller == null || !_controller.value.isInitialized) {
      return const Text(
        'Escolha uma câmera',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      final size = MediaQuery.of(context).size;

      if (!_controller.value.isInitialized) {
        return SizedBox.shrink();
      }
      return ClipRect(
        child: Container(
            child: Stack(
          children: <Widget>[
            Positioned.fill(
                child: Transform.scale(
              scale: _controller.value.aspectRatio / size.aspectRatio,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: CameraPreview(_controller),
                ),
              ),
            )),
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
                  ))
          ],
        )),
      );
    }
  }

  /// Display the thumbnail of the captured image or video.
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

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller.dispose();
    }
    _controller = CameraController(cameraDescription, ResolutionPreset.medium,
        autoFocusMode: AutoFocusMode.continuous);

    _controller.addListener(() {
      if (mounted)
        setState(() {
          scannerSize = (MediaQuery.of(context).size.width / 1.3);
        });
      if (_controller.value.hasError) {
        Utils.showInSnackBar(_scaffoldKey,
            'Erro na câmera: ${_controller.value.errorDescription}');
      }
    });

    try {
      await _controller.initialize();
    } on CameraException catch (e) {
      _showCameraException(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void setProcessingState(bool value) {
    setState(() {
      isProcessing = value;
    });
  }

  void onTakePictureButtonPressed() {
    try {
      setProcessingState(true);
      deviceHasFlash();
      _controller.pausePreview();
      _controller.setFlash(mode: FlashMode.off);

      takePicture().then((String filePath) async {
        if (mounted) {
          setState(() {
            originalImagePath = filePath;
          });
          if (filePath == null) return;

          // Analisa a turbidez
          var originalImage = await ImageHelper.getImage(filePath);
          var exifTags =
              await readExifFromBytes(File(filePath).readAsBytesSync());
          var exposureTime = ImageHelper.getExposureTime(exifTags);
          var iso = ImageHelper.getIso(exifTags);

          // Ativa o flash
          if (_hasFlash) {
            _controller.setFlash(mode: FlashMode.torch);

            takePicture().then((String _flashImagepath) async {
              _controller.setFlash(mode: FlashMode.off);

              if (mounted) {
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
                turbidity = (turbidity / clarityAmount) * 1000;

                // Apresenta a turbidez final
                Utils.showInSnackBar(_scaffoldKey,
                    "$turbidity - ${Turbidity.getNTURange(turbidity)}");
              }
            });
          }
          // Caso o dispositivo não tenha flash
          else {
            var turbidity = Turbidity.getTurbidity(originalImage,
                exposureTime: exposureTime,
                isoSpeed: iso,
                sampleSize: scannerSize.round());

            // Apresenta a turbidez final
            Utils.showInSnackBar(_scaffoldKey,
                "$turbidity - ${Turbidity.getNTURange(turbidity)}");

          }

          _controller.resumePreview();
          setProcessingState(false);
        }
      });
    } on Exception catch (e) {
      _controller.setFlash(mode: FlashMode.off);
      _controller.resumePreview();
      Utils.showInSnackBar(_scaffoldKey, e.toString());
    }
  }

  Future<String> takePicture() async {
    if (!_controller.value.isInitialized) {
      Utils.showInSnackBar(_scaffoldKey, 'Erro: selecione uma câmera antes.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/LiquiQuali';
    bool exist = await File(dirPath).exists();
    if (!exist) {
      Directory(dirPath).create(recursive: true);
    }

    final String filePath = '$dirPath/${timestamp()}.png';

    if (_controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await _controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }

    return filePath;
  }

  void _showCameraException(CameraException e) {
    Utils.logError(e.code, e.description);
    Utils.showInSnackBar(_scaffoldKey, 'Error: ${e.code}\n${e.description}');
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: MainCamera());
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    Utils.logError(e.code, e.description);
  }
  runApp(CameraApp());
}
