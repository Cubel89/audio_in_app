## 4.1.0

* **New (non-breaking)**: load audio from a local file on the device filesystem via `createNewAudioCache(..., source: AudioInAppSource.file)`, passing an absolute path as `route`. Files are loaded with `SoLoud.loadFile` under the hood, while assets keep using `SoLoud.loadAsset`. Added the `AudioInAppSource { asset, file }` enum; `source` defaults to `AudioInAppSource.asset`.
* **New (non-breaking)**: `bool isPlaying(String playerId)` returns whether the last started voice (determined or background) is still sounding, so you can detect when a one-shot sound has finished.
* Fully backwards compatible: the previous API is unchanged. Callers that omit `source` keep loading from assets exactly as before.

## 4.0.0

* **BREAKING (engine)**: Replaced the internal `audioplayers` engine with `flutter_soloud` (SoLoud C++ engine via FFI). The public Dart API of `AudioInApp` is unchanged — no call sites need to be updated — but the platform setup requirements below make this a major release.
* **BREAKING (SDK)**: Minimum Flutter raised to `>=3.41.0` and Dart to `>=3.11.0` (required by `flutter_soloud`).
* **BREAKING (platform setup)**:
  * **Web**: add the two `flutter_soloud` scripts to your `web/index.html` (see README).
  * **Linux**: install the ALSA development library (`libasound2-dev` on Debian/Ubuntu).
  * **iOS/macOS**: when creating release archives, set the Runner target's *Strip Style* to *Non-Global Symbols*.
* **Behavior change**: one-shot (`determined`) effects now overlap when retriggered (each play creates a new voice), instead of restarting. Background audio keeps a single looping voice per id.
* Fixed: short effects no longer fail on Windows release (the original motivation for the migration).
* Removed the iOS priming workaround and the Android `AudioContext`/audio-focus workaround — no longer needed with SoLoud.

## 3.1.1

* Removed debug logging that was accidentally shipped in 3.1.0. No functional changes.

## 3.1.0

* Fixed: background music was silent on iOS. The release mode is now set before the iOS priming step; with the default release mode, the priming `stop()` released the player's source and the later `resume()` produced no sound.
* Fixed: on Android, one-shot effects stole the audio focus and paused the app's own background music. A global `AudioContext` with `AndroidAudioFocus.none` is now configured so effects and music coexist.

## 3.0.0

* **BREAKING**: Updated audioplayers from ^5.2.0 to ^6.5.1
* **BREAKING**: Minimum Dart SDK raised to >=3.6.0
* **BREAKING**: Minimum Flutter SDK raised to >=3.13.0
* **BREAKING**: Removed `audioCacheMap` getter (use `cachedPlayerIds` instead)
* **BREAKING**: Multiple background audios can now play simultaneously (previously, playing one stopped all others)
* Removed `universal_io` dependency (replaced with `flutter/foundation.dart` for web compatibility)
* Added web platform support
* Independent volume control per background audio
* Improved type safety (proper types instead of dynamic)
* Fixed async forEach anti-pattern (was not awaiting iterations)
* Removed deprecated `_ambiguate` helper
* Code quality improvements and full API documentation

## 2.1.1

* Error correction

## 2.1.0

* Updated the "audioplayers" version to 5.2.0
* Error correction

## 2.0.0 (Do not use this version because it gives an error.)

* Updated the "audioplayers" version to 5.2.0
* Error correction


## 1.0.0

* Load the audio to be able to use it later
* Play background audio
* Play punctual audio
* Delete cached loaded audio
* Change sound volume
