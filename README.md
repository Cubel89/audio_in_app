# audio_in_app

A Flutter package for playing audio files. Ideal for games or applications with sound.

Supports Android, iOS, macOS, Windows, Linux, and Web.

## Getting started and Usage


1 - We import the Audio_in_app package.

```dart
import 'package:audio_in_app/audio_in_app.dart';
```

2 - We create a variable of the AudioInApp class.
```dart
AudioInApp _audioInApp = AudioInApp();
```

3 - We load the audios that we are going to use later with the `createNewAudioCache()` method. Here we will have to insert an id to call it later of type String, the path is of type String where the audio being inside the `"assets"` folder and the type of audio, punctual or background. (See following examples).

3.1 - If it is a punctual audio (used in button presses, character jumps or shots).
```dart
await _audioInApp.createNewAudioCache(playerId: 'button', route: 'audio/button.wav', audioInAppType: AudioInAppType.determined);
```

3.2 - If it is background audio (used during gameplay). Background audio has several differences from spot audio. The differences are as follows.
<br>
- Background audio plays infinitely in a loop until you decide to stop it.
- Multiple background audios can play simultaneously with independent volume control.
- Use `stopBackground()` to stop all background audios at once, or `stop(playerId:)` to stop a specific one.

```dart
await _audioInApp.createNewAudioCache(playerId: 'intro1', route: 'audio/intro_1.wav', audioInAppType: AudioInAppType.background);
```
4 - Play audio.

```dart
await _audioInApp.play(playerId: 'button');
```

or

```dart
await _audioInApp.play(playerId: 'intro1');
```

5 - Stop a specific audio.

```dart
await _audioInApp.stop(playerId: 'intro1');
```

6 - Stop all background audios.

```dart
await _audioInApp.stopBackground();
```

7 - Change volume of a specific audio (0.0 to 1.0).

```dart
await _audioInApp.setVol('intro1', 0.5);
```


### Example

There is a basic example in the [example](https://github.com/Cubel89/audio_in_app/tree/3.0.0/example) folder of the project.
<br>
But here we add a quick example based on the example that is in the project.

<br>

1 - In this case we have a loading page, where we wait 1.5 seconds and then proceed to load all the audios that are going to be used on the next page.

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
    Future.delayed(Duration(milliseconds: 1500)).then((value) => goToMain());
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

2 - This would be the next page where these sounds will be used depending on the buttons pressed.


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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                margin: EdgeInsets.only(bottom: 30),
                child: Text('Main Activity')),
            OutlinedButton(
              onPressed: () => _audioInApp.play(playerId: 'intro1'),
              child: Text("Play background intro 1"),
            ),
            OutlinedButton(
              onPressed: () => _audioInApp.play(playerId: 'intro2'),
              child: Text("Play background intro 2"),
            ),
            OutlinedButton(
              onPressed: () => _audioInApp.stop(playerId: 'intro1'),
              child: Text("Stop intro 1 only"),
            ),
            OutlinedButton(
              onPressed: () => _audioInApp.setVol('intro1', 0.3),
              child: Text("Lower volume intro 1"),
            ),
            OutlinedButton(
              onPressed: () => _audioInApp.play(playerId: 'button'),
              child: Text("Play Button Sound"),
            ),
            OutlinedButton(
              onPressed: () => _audioInApp.stopBackground(),
              child: Text("Stop all background sounds"),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Additional information

This package uses the [audioplayers](https://pub.dev/packages/audioplayers) 6.x package and tries to make things easier for new users. Feel free to collaborate to add new features or improve part of the code currently created. Any help will be welcome.
