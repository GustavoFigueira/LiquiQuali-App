import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:aeyrium_sensor/aeyrium_sensor.dart';
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animator/animator.dart';

import 'pages/main_camera.dart';
import 'pages/preview_page.dart';
import 'pages/widgets/main_menu.dart';

// TODO: fazer alerta a ser apresentando uma vez falandoq ue o flahs será ativado
// TODO: funncção de compartilhar imagem com textos da medição

class MyApp extends StatefulWidget {
  const MyApp(this._permission);

  final Permission _permission;

  @override
  _MyAppState createState() => _MyAppState(_permission);
}

class _MyAppState extends State<MyApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  String originalImagePath;
  String flashImagePath;
  bool _hasFlash = false;
  bool isProcessing = false;
  int pitch = 0;
  double scannerSize = 200;
  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  _MyAppState(this._permission);

  final Permission _permission;
  PermissionStatus _permissionStatus = PermissionStatus.undetermined;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
                  onPressed: () {},
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
                )
              ],
            )));
  }

  Widget _cameraPreviewWidget() {
    return isProcessing
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
                        border:
                            Border.all(color: Colors.greenAccent, width: 2))),
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
                                  ? Colors.greenAccent
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

  // Future<String> takePicture() async {
  //   if (!_controller.value.isInitialized) {
  //     Utils.showInSnackBar(_scaffoldKey, 'Erro: selecione uma câmera antes.');
  //     return null;
  //   }

  //   final Directory extDir = await getApplicationDocumentsDirectory();
  //   final String dirPath = '${extDir.path}/LiquiQuali';
  //   bool exist = await File(dirPath).exists();
  //   if (!exist) {
  //     Directory(dirPath).create(recursive: true);
  //   }

  //   final String filePath = '$dirPath/${timestamp()}.png';

  //   if (_controller.value.isTakingPicture) {
  //     // A capture is already pending, do nothing.
  //     return null;
  //   }

  //   try {
  //     await _controller.takePicture(filePath);
  //   } on CameraException catch (e) {
  //     _showCameraException(e);
  //     return null;
  //   }

  //   return filePath;
  // }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: MainCamera());
  }
}

void main() {
  runApp(CameraApp());
}
