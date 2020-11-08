
import 'package:flutter/material.dart';
import 'pages/main_camera.dart';

// TODO: fazer alerta a ser apresentando uma vez falandoq ue o flahs será ativado
// TODO: funncção de compartilhar imagem com textos da medição

class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: MainCamera());
  }
}

void main() {
  runApp(CameraApp());
}
