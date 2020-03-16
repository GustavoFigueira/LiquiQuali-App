import 'dart:async';
import 'dart:io';
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as image;
import 'package:torch/torch.dart';

import 'helpers/turbidity.dart';
import 'helpers/utils.dart';
import 'pages/preview_page.dart';

class CameraExampleHome extends StatefulWidget {
  @override
  _CameraExampleHomeState createState() {
    return _CameraExampleHomeState();
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

void logError(String code, String message) =>
    print('Error: $code\nError Message: $message');

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver {
  CameraController controller;
  String originalImagePath;
  String flashImagePath;
  CameraLensDirection currentCamera;
  final PermissionHandler _permissionHandler = PermissionHandler();

  Future<void> requestPermissions(List<PermissionGroup> permissions,
      {Function onPermissionDenied}) async {
    var result = await _permissionHandler.requestPermissions(permissions);
    for (PermissionGroup permission in permissions) {
      if (result[permission] != PermissionStatus.granted) {
        onPermissionDenied();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    requestPermissions(<PermissionGroup>[PermissionGroup.camera]).then((bool) {
      onNewCameraSelected(cameras[0]);
    });
    setLastAnalysis();
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
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        onNewCameraSelected(controller.description);
      }
    }
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    if (controller == null || !controller.value.isInitialized) {
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

      if (!controller.value.isInitialized) {
        return Container();
      }
      return ClipRect(
        child: Container(
          child: Transform.scale(
            scale: controller.value.aspectRatio / size.aspectRatio,
            child: Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: CameraPreview(controller),
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
              groupValue: controller?.description,
              value: cameraDescription,
              onChanged: controller != null && controller.value.isRecordingVideo
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

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
    );

    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Erro na câmera: ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
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
        bool hasTorch = await Torch.hasTorch;
        Torch.flash(Duration(milliseconds: 300));

        takePicture().then((String _flashImagepath) async {
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

        showInSnackBar("$turbidity - ${Turbidity.getNTURange(turbidity)}");
      }
    });
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Erro: selecione uma câmera antes.');
      return null;
    }

    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/LiquiQuali';
    bool exist = await File(dirPath).exists();
    if (!exist) {
      Directory(dirPath).create(recursive: true);
    }

    final String filePath = '$dirPath/${timestamp()}.png';

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }

    return filePath;
  }

  void _showCameraException(CameraException e) {
    logError(e.code, e.description);
    showInSnackBar('Error: ${e.code}\n${e.description}');
  }
}

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraExampleHome(),
    );
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    logError(e.code, e.description);
  }
  runApp(CameraApp());
}
