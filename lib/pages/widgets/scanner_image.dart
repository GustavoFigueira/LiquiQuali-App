import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class _ScannerBarAnimation extends StatelessWidget {
  @override
  Widget build(BuildContext context) { 
    return null;
  }
}

class _ScannerContentView extends StatelessWidget {
  _ScannerContentView({
    @required this.edgeLength,
    @required this.child,
    this.backgroundColor,
    this.padding,
  });

  final double edgeLength;

  final Color backgroundColor;

  final EdgeInsets padding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: edgeLength,
      height: edgeLength,
      color: backgroundColor,
      child: Padding(
        padding: padding,
        child: child
      ),
    );
  }
}