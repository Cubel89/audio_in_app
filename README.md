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

5 - Stop a specific background audio.

```dart
await _audioInApp.stopBackground(playerId: 'intro1');
```

6 - Stop all background audios at once.

```dart
await _audioInApp.stopBackground();
```

7 - Change volume of a specific audio (0.0 to 1.0).

```dart
await _audioInApp.setVol('intro1', 0.5);
```

### Load audio from a local file

Since 4.1.0 you can play a file that lives on the device filesystem (downloaded, recorded, etc.) instead of a bundled asset. Pass `source: AudioInAppSource.file` and an **absolute path** as `route`. This is non-breaking: `source` defaults to `AudioInAppSource.asset`, so any existing call keeps loading from assets exactly as before.

```dart
// 'route' must be an ABSOLUTE path to a local file on the device.
await _audioInApp.createNewAudioCache(
  playerId: 'note',
  route: '/data/user/0/com.example.app/files/note.m4a',
  audioInAppType: AudioInAppType.determined,
  source: AudioInAppSource.file,
);

await _audioInApp.play(playerId: 'note');
```

> **Web:** loading from a local file is **not supported on Web** (it relies on
> `SoLoud.loadFile`, which is unavailable there). On Web, `source:
> AudioInAppSource.file` fails gracefully and `createNewAudioCache` returns
> `false` — use bundled assets on Web.

Once cached, you can `play` it as many times as you want, exactly like an asset
(the `source` only matters when caching).

Bundled assets keep the same call as always (no `source` needed):

```dart
await _audioInApp.createNewAudioCache(
  playerId: 'button',
  route: 'audio/button.wav',
  audioInAppType: AudioInAppType.determined,
);
```

### Check if an audio is still playing

Since 4.1.0 you can ask whether the last started voice for a `playerId` is still sounding with `isPlaying(playerId)`. It returns `false` once the voice has finished, which is handy to detect the end of a one-shot (`determined`) sound, e.g. to reset a play button.

```dart
final bool stillPlaying = _audioInApp.isPlaying('note');
if (!stillPlaying) {
  // The one-shot finished: update your UI here.
}
```


### Example

There is a basic example in the [example](https://github.com/Cubel89/audio_in_app/tree/4.1.0/example) folder of the project.
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
              onPressed: () => _audioInApp.stopBackground(playerId: 'intro1'),
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

## Platform setup

Since 4.0.0 the audio engine is [flutter_soloud](https://pub.dev/packages/flutter_soloud) (SoLoud C++ via FFI). Some platforms need extra setup:

### Web

Add these two scripts to your `web/index.html`, inside `<head>`:

```html
<script src="assets/packages/flutter_soloud/web/libflutter_soloud_plugin.js" defer></script>
<script src="assets/packages/flutter_soloud/web/init_module.dart.js" defer></script>
```

### Linux

Install the ALSA development library:

```bash
sudo apt-get install libasound2-dev   # Debian/Ubuntu
# alsa-lib (Arch) · alsa-devel (openSUSE)
```

### iOS / macOS

When creating **release archives** in Xcode, set the `Runner` target's **Strip Style** to **Non-Global Symbols** (Build Settings → Deployment), so the native FFI symbols are not stripped.

### Android / Windows

No extra setup: the native engine is built automatically via CMake.

## Additional information

This package uses the [flutter_soloud](https://pub.dev/packages/flutter_soloud) engine under the hood and tries to make things easier for new users. Feel free to collaborate to add new features or improve part of the code currently created. Any help will be welcome.
