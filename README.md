# audio_in_app

A Flutter plugin for playing audio files. Ideal for games or applications with sound.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting started

TODO: List prerequisites and provide or point to information on how to
start using the package.

## Usage

TODO: Include short and useful examples for package users. Add longer examples
to `/example` folder. 

```dart
const like = 'sample';
```


### Generating boilerplate for Value Types

Value types require a bit of boilerplate in order to connect it to generated
code. Luckily, even this bit of boilerplate can be automated using code
snippets support in your favourite text editor. For example, in IntelliJ you
can use the following live template:


Pagina de carga, se espera un segundo y medio y acto seguido carga en caché los audios que vamos a necesitar en la siguiente pagina.

```dart
import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';

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
    await _audioInApp.createNewAudioCache(playerId: 'intro1', route: 'audio/intro_1.wav', audioInAppType: AudioInAppType.background);
    await _audioInApp.createNewAudioCache(playerId: 'intro2', route: 'audio/intro_2.wav', audioInAppType: AudioInAppType.background);
    await _audioInApp.createNewAudioCache(playerId: 'button', route: 'audio/button.wav', audioInAppType: AudioInAppType.determined);
    Navigator.pushReplacementNamed(context, 'main');
  }
}
```

Pagina home de la aplicación. Lugar donde vamos a reproducir los audios.

```dart
import 'package:audio_in_app/audio_in_app.dart';
import 'package:flutter/material.dart';

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
    await _audioInApp.stopBackgroun();
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
```

## Additional information

TODO: Tell users more about the package: where to find more information, how to 
contribute to the package, how to file issues, what response they can expect 
from the package authors, and more.
