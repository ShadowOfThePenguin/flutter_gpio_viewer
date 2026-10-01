import 'package:flutter/material.dart';

import 'src/gpio_source.dart';
import 'src/gpio_viewer_page.dart';

void main() {
  runApp(const MainApp(loader: loadGpioChips));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.loader});

  final GpioLoader loader;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPIO Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: GpioViewerPage(loader: loader),
    );
  }
}
