import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fflashlight/fflashlight.dart';

import 'helpers/turbidity.dart';
import 'helpers/utils.dart';
import 'pages/preview_page.dart';

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

class _MainCameraState extends State<MainCamera> with WidgetsBindingObserver {
  CameraController _controller;
  String originalImagePath;
  String flashImagePath;
  CameraLensDirection currentCamera;
  final PermissionHandler _permissionHandler = PermissionHandler();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _hasFlashlight = false;
  bool enableTorch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    requestPermissions(<PermissionGroup>[PermissionGroup.camera]).then((bool) {
      onNewCameraSelected(cameras[0]);
    });
    initPlatformState();
    setLastAnalysis();
  }

  Future<void> initPlatformState() async {
    bool hasFlashlight;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      hasFlashlight = await Fflashlight.hasFlashlight;
    } on PlatformException {
      hasFlashlight = false;
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _hasFlashlight = hasFlashlight;
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
        body: Stack(
          children: <Widget>[
            _cameraPreviewWidget(),
            _customAppBar(),
            _cameraTogglesRowWidget(),
          ],
        ));
  }

  Widget _takePhotoButton() {
    return Container(
        margin: EdgeInsets.symmetric(vertical: 30),
        child: RaisedButton.icon(
            elevation: 4.0,
            icon: Icon(Icons.photo_camera, color: Colors.white),
            color: Colors.black54,
            label: Text("Analisar",
                style: TextStyle(color: Colors.white, fontSize: 16.0)),
            onPressed: () => onTakePictureButtonPressed()));
  }

  Widget _customAppBar() {
    return Positioned(
        child: AppBar(
      centerTitle: true,
      title: Text("LiquiQuali",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            shadows: <Shadow>[
              Shadow(
                  offset: Offset(0, 0.3), blurRadius: 5, color: Colors.black54)
            ],
          )),
      backgroundColor: Colors.transparent,
    ));
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
        return Container();
      }
      return ClipRect(
        child: Container(
          child: Transform.scale(
            scale: _controller.value.aspectRatio / size.aspectRatio,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: CameraPreview(_controller),
              ),
            ),
          ),
        ),
      );
    }
  }

  /// Display the thumbnail of the captured image or video.
  Widget _thumbnailWidget() {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            originalImagePath == null
                ? Container()
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
                  )
          ],
        ),
      ),
    );
  }

  Widget _cameraTogglesRowWidget() {
    final List<Widget> toggles = <Widget>[];

    // TODO: trocar sizedebox por container

    if (cameras.isEmpty) {
      return const Text('Nenhuma câmera encontrada!');
    } else {
      for (CameraDescription cameraDescription in cameras) {
        toggles.add(
          SizedBox(
            width: 90.0,
            child: RadioListTile<CameraDescription>(
              title: Icon(getCameraLensIcon(cameraDescription.lensDirection),
                  color: Colors.white),
              groupValue: _controller?.description,
              value: cameraDescription,
              onChanged:
                  _controller != null && _controller.value.isRecordingVideo
                      ? null
                      : onNewCameraSelected,
            ),
          ),
        );
      }

      toggles.add(_thumbnailWidget());
    }

    return Positioned(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[_takePhotoButton(), Row(children: toggles)]));
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (_controller != null) {
      await _controller.dispose();
    }
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );

    _controller.addListener(() {
      if (mounted) setState(() {});
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

  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) async {
      if (mounted) {
        setState(() {
          originalImagePath = filePath;
        });
        if (filePath == null) return;

        // Analisa a turbidez
        var finalImage = await ImageHelper.getImage(filePath);
        var exifTags =
            await readExifFromBytes(File(filePath).readAsBytesSync());
        var exposureTime = ImageHelper.getExposureTime(exifTags);
        var iso = ImageHelper.getIso(exifTags);

        var turbidity = Turbidity.getTurbidity(finalImage,
            exposureTime: exposureTime, isoSpeed: iso);

        // Ativa o flash
        if (_hasFlashlight) {

          _toggleTorch(true);
          
          takePicture().then((String _flashImagepath) async {
            _toggleTorch(false);
            if (mounted) {
              setState(() {
                flashImagePath = _flashImagepath;
              });
              if (_flashImagepath == null) return;

              var flashImage = await ImageHelper.getImage(_flashImagepath);

              finalImage =
                  ImageHelper.getImageSubtraction(finalImage, flashImage);

              await ImageHelper.saveImage(finalImage, flashImagePath)
                  .then((String newPath) async {
                setState(() {
                  originalImagePath = newPath;
                });
              });
            }
          });
        }

        Utils.showInSnackBar(
            _scaffoldKey, "$turbidity - ${Turbidity.getNTURange(turbidity)}");
      }
    });
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

   /// Toggle Torch
  Future<void> _toggleTorch(bool value) async {
    bool hasTorch = false;

    if (_controller != null) {
      hasTorch = await _controller.hasTorch;
    }

    if (hasTorch) {
      enableTorch = value;
      if (enableTorch) {
        _controller.torchOn();
      } else {
        _controller.torchOff();
      }
    }

    setState(() {});
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainCamera(),
    );
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
