## 4.2.0

* **New (non-breaking): background channels with crossfade.** A channel is an
  exclusive logical line of background playback that holds one active track and
  crossfades smoothly when you switch tracks. Backed by a real `flutter_soloud`
  mixing bus per channel (native master volume + fades). New API:
  * `createChannel({channelId, volume})` — idempotent; re-creating updates volume.
  * `playChannel({channelId, playerId, transitionDuration})` — instant switch with
    `Duration.zero`, crossfade otherwise. The `Future` completes once the transition
    is safely started, not after the full fade. Rapid changes (A→B→C, A→B→A) resolve
    to a single surviving track with no orphan voices.
  * `stopChannel({channelId, fadeOutDuration})` — fades tracks out; channel stays reusable.
  * `pauseChannel` / `resumeChannel` — compose with the automatic
    background/foreground pause (a channel resumes only when no pause reason remains).
  * `setChannelVolume({channelId, volume})` — master volume without cancelling fades.
  * `activePlayerIdInChannel`, `isChannelPlaying`, `isChannelPaused` — queries.
* **Compatibility:** the previous API is unchanged. `stop`, `stopBackground(playerId:)`,
  `setVol` and `isPlaying` now also reach voices playing inside channels, so the same
  `playerId` can play both as a plain background and inside a channel simultaneously.
  Recaching a `playerId` that is active in a channel is rejected (returns `false`).
* **Validation:** invalid arguments (empty id, volume outside `0..1`, negative
  duration) throw `ArgumentError`; engine/operational errors return `false`.
* **Internals:** the channel state machine is a pure-Dart reducer covered by unit
  tests; the SoLoud engine is isolated behind an injectable backend. Verified with
  unit tests plus integration tests on macOS (native) exercising the real mixing bus,
  crossfade, legacy/channel coexistence and regression of the 4.1.x behaviour. Web
  compiles (Wasm dry run passes); channel runtime on Web is not yet verified.

## 4.1.1

* **Fix (crash on cold start)**: free the native SoLoud engine on `AppLifecycleState.detached`. The engine is a native (C++) singleton that outlives the Dart isolate within the same process (e.g. Android re-creating the Activity without killing the process). Previously the engine kept its FFI `NativeCallable` listeners pointing at the destroyed isolate, so a later native `voiceEnded`/`stateChanged` aborted the VM with `SIGABRT "Callback invoked after it has been deleted"` on the next cold start. The observer now calls `SoLoud.deinit()` on `detached` (which disposes the native callables). Only on `detached`, never on `paused` (that would silence audio when minimizing or showing an ad). No API changes.

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
