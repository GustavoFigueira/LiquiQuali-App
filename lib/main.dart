import 'dart:async';
import 'dart:io';
import 'package:image/image.dart' as image;
import 'package:LiquiQuali/helpers/utils.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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
  String imagePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    onNewCameraSelected(cameras[0]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App state changed before we got the chance to initialize.
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
            imagePath == null
                ? Container()
                : GestureDetector(
                    child: SizedBox(
                        child: Image.file(
                      File(imagePath),
                      width: 64.0,
                      height: 64.0,
                    )),
                    onTap: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) {
                      return PreviewPage(imagePath);
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
      enableAudio: false,
    );

    // If the controller is updated then update the UI
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
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
          imagePath = filePath;
        });
        if (filePath != null) showInSnackBar('Picture saved to $filePath');

        image.Image finalImage = await ImageHelper.getImage(filePath);

        for (var i = 0; i < finalImage.width; i++) {
          for (var j = 0; j < finalImage.height; j++) {
            var color = Color(finalImage.getPixelSafe(i, j));
            if (color.red > 150) {
              finalImage.setPixelSafe(i, j, Colors.black.value);
            } else {
              finalImage.setPixelSafe(i, j, Colors.white.value);
            }
          }
        }

        ImageHelper.saveImage(finalImage, imagePath)
            .then((String newPath) async {
          setState(() {
            imagePath = newPath;
          });
        });
      }
    });
  }

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      showInSnackBar('Erro: selecione uma câmera antes.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/Pictures/LiquiQuali';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

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
