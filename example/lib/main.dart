import 'package:flutter/material.dart';
import 'dart:developer';
import 'package:audio_in_app/audio_in_app.dart';

/// This file is an all-in-one example. If you want to use it in several files, you can follow the file "main_2.dart"

/// File "/main_2.dart"
void main() {
  runApp(MyApp());
}



/// File "/src/app.dart"
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






/// File "/src/routes/routes.dart"
Map<String, WidgetBuilder> getAplicationRouter(){
  return <String, WidgetBuilder>{
    'loading'                     : (BuildContext context) => LoadingActivity(),
    'main'                        : (BuildContext context) => MainActivity(),
  };
}




/// File "/src/activities/loading_activity.dart"
class LoadingActivity extends StatefulWidget {
  @override
  State<LoadingActivity> createState() => _LoadingActivityState();
}

class _LoadingActivityState extends State<LoadingActivity> {
  AudioInApp _audioInApp = AudioInApp();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 1500)).then((value) =>   goToMain());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Loading Activity'),
      ),
    );
  }


  Future<void> goToMain() async {
    //_audioInApp.initialize();
    await _audioInApp.createNewAudioCache(playerId: 'intro1', route: 'audio/intro_1.wav', audioInAppType: AudioInAppType.background);
    await _audioInApp.createNewAudioCache(playerId: 'intro2', route: 'audio/intro_2.wav', audioInAppType: AudioInAppType.background);
    await _audioInApp.createNewAudioCache(playerId: 'button', route: 'audio/button.wav', audioInAppType: AudioInAppType.determined);
    log(_audioInApp.audioCacheMap.toString(), name: 'LoadingActivity');

    Navigator.pushReplacementNamed(context, 'main');
  }
}


/// File "/src/activities/main_activity.dart"
class MainActivity extends StatefulWidget {
  @override
  State<MainActivity> createState() => _MainActivityState();
}

class _MainActivityState extends State<MainActivity> {
  AudioInApp _audioInApp = AudioInApp();


  @override
  void initState() {
    super.initState();
  }

  Future<void> play_intro_1() async {
    await _audioInApp.play(playerId: 'intro1');
  }
  Future<void> play_intro_2() async {
    await _audioInApp.play(playerId: 'intro2');
  }
  Future<void> stop_background() async {
    await _audioInApp.stopBackground();
  }


  Future<void> play_button() async {
    await _audioInApp.play(playerId: 'button');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                margin: EdgeInsets.only(bottom: 30),
                child: Text('Main Activity')
            ),
            OutlinedButton(
              onPressed: () {
                play_intro_1();
              },
              child: Text("Play background intro 1"),
            ),
            OutlinedButton(
              onPressed: () {
                play_intro_2();
              },
              child: Text("Play background intro 2"),
            ),
            OutlinedButton(
              onPressed: () {
                play_button();
              },
              child: Text("Play Button Sound"),
            ),
            OutlinedButton(
              onPressed: () {
                stop_background();
              },
              child: Text("Stop background sound"),
            )
          ],
        ),
      ),
    );
  }
}




