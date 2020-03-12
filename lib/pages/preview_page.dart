import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PreviewPage extends StatefulWidget {
  final String imagePath;
  @override
  _PreviewPageState createState() => _PreviewPageState();

  PreviewPage(this.imagePath);
}

class _PreviewPageState extends State<PreviewPage> {
  @override
  initState() {
    SystemChrome.setEnabledSystemUIOverlays([]);
    super.initState();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medição'),
        backgroundColor: Colors.transparent,
      ),
      backgroundColor: Colors.black,
      body: GestureDetector(
        child: Center(
          child: Hero(
            tag: 'imageHero',
            child:  Image.file(File(widget.imagePath))
          ),
        ),
        onTap: () {
          Navigator.pop(context);
        },
      ),
    );
  }
}