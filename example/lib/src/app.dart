import 'package:example/src/routes/routes.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'audio_in_app Example',
      debugShowCheckedModeBanner: false,
      initialRoute: 'loading',
      routes: getApplicationRouter(),
    );
  }
}
