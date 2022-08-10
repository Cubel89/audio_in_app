
import 'package:example/src/routes/routes.dart';
import 'package:flutter/material.dart';


class MyApp extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _MyApp();
  }
}

class _MyApp extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Example App',
      debugShowCheckedModeBanner: false,
      initialRoute: 'loading',
      routes: getAplicationRouter(),
    );
  }
}