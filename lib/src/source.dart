import 'dart:developer';

import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/widgets.dart';

/// A singleton class that manages audio playback in your app.
///
/// Supports two types of audio:
/// - [AudioInAppType.determined]: Short, one-shot sounds (buttons, effects).
/// - [AudioInAppType.background]: Looping audio (music, ambient). Multiple
///   background audios can play simultaneously with independent control.
///
/// Audio is automatically paused when the app goes to background and resumed
/// when it comes back to foreground.
class AudioInApp with WidgetsBindingObserver {
  static const _nameLog = 'AudioInApp';
  bool _isRegistered = false;
  bool _audioPermission = true;
  bool _audioPermissionUser = true;
  bool _audioContextConfigured = false;

  final Map<String, AudioInAppType> _audioCacheType = {};
  final Map<String, AudioPlayer> _audioCacheMap = {};
  final List<String> _audioBackgroundCacheList = [];
  final Map<String, AudioPlayer> _audioBackgroundCacheMap = {};
  final Set<String> _audioBackgroundPlayingIds = {};

  // Singleton
  static final AudioInApp _singletonAudioInApp = AudioInApp._internal();
  factory AudioInApp() {
    return _singletonAudioInApp;
  }
  AudioInApp._internal();

  /// Registers a [WidgetsBinding] observer.
  ///
  /// This must be called for auto-pause and resume to work properly.
  void _initialize() {
    if (_isRegistered) {
      return;
    }
    _isRegistered = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Configura una sola vez el AudioContext global para que el audio de la app
  /// no robe el foco a su propia música de fondo. En Android, el foco por
  /// defecto ('gain') hace que al reproducir un efecto el sistema pause el
  /// resto de reproductores (incluida la música de fondo de la propia app);
  /// con 'none' los efectos y la música coexisten. En iOS se mantiene la
  /// categoría 'playback' (la de por defecto, que ya reproduce correctamente).
  Future<void> _ensureAudioContext() async {
    if (_audioContextConfigured) return;
    _audioContextConfigured = true;
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: false,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.none,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ));
    } catch (e) {
      log('No se pudo configurar el AudioContext: $e', name: _nameLog);
    }
  }

  /// Disposes the [WidgetsBinding] observer.
  void dispose() {
    if (!_isRegistered) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      log('Paused', name: _nameLog);
      _audioPermission = false;
      for (final playerId in _audioBackgroundPlayingIds) {
        final player = _audioBackgroundCacheMap[playerId];
        if (player != null && player.state == PlayerState.playing) {
          await player.pause();
        }
      }
    }
    if (state == AppLifecycleState.resumed) {
      log('Resumed', name: _nameLog);
      _audioPermission = true;
      if (_audioPermissionUser) {
        for (final playerId in _audioBackgroundPlayingIds) {
          final player = _audioBackgroundCacheMap[playerId];
          if (player != null) {
            await player.resume();
          }
        }
      }
    }
  }

  /// Adds an audio file to the cache. This is required before playing.
  ///
  /// [playerId] is a unique identifier to reference this audio later.
  /// [route] is the asset path relative to the `assets` folder (e.g. `'audio/button.wav'`).
  /// [audioInAppType] defines the playback behavior:
  /// - [AudioInAppType.determined]: One-shot, low latency.
  /// - [AudioInAppType.background]: Looping. Multiple backgrounds can play simultaneously.
  ///
  /// Returns `true` if the audio was cached successfully, `false` on error.
  Future<bool> createNewAudioCache({
    required String playerId,
    required String route,
    required AudioInAppType audioInAppType,
  }) async {
    _initialize();
    await _ensureAudioContext();
    log('createNewAudioCache $playerId', name: _nameLog);
    try {
      if (audioInAppType == AudioInAppType.determined) {
        final audio = AudioPlayer(playerId: playerId);
        await audio.setVolume(0.0);
        await audio.setSource(AssetSource(route));
        await audio.setReleaseMode(ReleaseMode.stop);
        // iOS workaround: prime the audio session by briefly playing at zero volume.
        // AVAudioPlayer on iOS requires at least one play cycle before resume()
        // works reliably from a cached state.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await audio.resume();
          await audio.stop();
        }
        await audio.setVolume(1.0);
        await audio.setPlayerMode(PlayerMode.lowLatency);
        _audioCacheMap[playerId] = audio;
      }

      if (audioInAppType == AudioInAppType.background) {
        final audio = AudioPlayer(playerId: playerId);
        await audio.setVolume(0.0);
        await audio.setSource(AssetSource(route));
        // El releaseMode debe fijarse ANTES del prime de iOS: con el release
        // por defecto, el stop() del prime libera el source en iOS y el
        // resume() posterior queda mudo. Con loop activo, stop() no lo libera.
        await audio.setReleaseMode(ReleaseMode.loop);
        // iOS workaround: prime the audio session by briefly playing at zero volume.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await audio.resume();
          await audio.stop();
        }
        await audio.setVolume(1.0);
        _audioBackgroundCacheMap[playerId] = audio;
      }

      if (!_audioBackgroundCacheList.contains(playerId)) {
        _audioBackgroundCacheList.add(playerId);
      }
      _audioCacheType[playerId] = audioInAppType;
    } catch (e) {
      log('ERROR', name: _nameLog);
      log(e.toString(), name: _nameLog);
      return false;
    }
    return true;
  }

  /// Starts playing the audio identified by [playerId].
  ///
  /// For [AudioInAppType.determined] audio: plays once and stops.
  /// For [AudioInAppType.background] audio: starts looping. Multiple background
  /// audios can play simultaneously. Use [stopBackground] to stop all, or
  /// [stop] to stop a specific one.
  ///
  /// Returns `false` if audio permission is disabled or the player is not cached.
  Future<bool> play({
    required String playerId,
  }) async {
    if (!_audioPermission) return false;
    if (!_audioPermissionUser) return false;
    log('play $playerId', name: _nameLog);
    if (!await _checkExistCache(playerId)) return false;
    if (_audioCacheType[playerId] == AudioInAppType.background) {
      await _playBackground(playerId);
    }
    if (_audioCacheType[playerId] == AudioInAppType.determined) {
      await _playDetermined(playerId);
    }
    return true;
  }

  /// Stops the audio identified by [playerId].
  ///
  /// Works for both determined and background audio types.
  /// Other background audios will continue playing unaffected.
  ///
  /// Returns `false` if the player is not cached.
  Future<bool> stop({
    required String playerId,
  }) async {
    log('stop $playerId', name: _nameLog);
    if (!await _checkExistCache(playerId)) return false;
    if (_audioCacheType[playerId] == AudioInAppType.background) {
      final player = _audioBackgroundCacheMap[playerId];
      if (player != null) await player.stop();
      _audioBackgroundPlayingIds.remove(playerId);
    }
    if (_audioCacheType[playerId] == AudioInAppType.determined) {
      final player = _audioCacheMap[playerId];
      if (player != null) await player.stop();
    }
    return true;
  }

  /// Stops background audio.
  ///
  /// If [playerId] is provided, stops only that specific background audio.
  /// If [playerId] is omitted, stops all background audios currently playing.
  /// Determined (one-shot) audios are not affected.
  ///
  /// Returns `false` if a [playerId] is provided but is not cached.
  Future<bool> stopBackground({String? playerId}) async {
    if (playerId != null) {
      log('stopBackground $playerId', name: _nameLog);
      if (!await _checkExistCache(playerId)) return false;
      final player = _audioBackgroundCacheMap[playerId];
      if (player != null) await player.stop();
      _audioBackgroundPlayingIds.remove(playerId);
    } else {
      log('stopBackground all', name: _nameLog);
      for (final itemPlayerId in _audioBackgroundCacheList) {
        final player = _audioBackgroundCacheMap[itemPlayerId];
        if (player != null) {
          await player.stop();
        }
      }
      _audioBackgroundPlayingIds.clear();
    }
    return true;
  }

  /// Changes the audio volume for [playerId]. Value between 0.0 and 1.0.
  ///
  /// Works independently per audio — changing one does not affect others.
  Future<void> setVol(String playerId, double vol) async {
    log('setVol $playerId', name: _nameLog);
    if (!await _checkExistCache(playerId)) return;
    if (_audioCacheType[playerId] == AudioInAppType.background) {
      final player = _audioBackgroundCacheMap[playerId];
      if (player != null) {
        await player.setVolume(vol);
      }
    }
    if (_audioCacheType[playerId] == AudioInAppType.determined) {
      final player = _audioCacheMap[playerId];
      if (player != null) {
        await player.setVolume(vol);
      }
    }
  }

  /// Removes the audio from the cache and releases its resources.
  ///
  /// The audio will no longer play until it is re-cached using [createNewAudioCache].
  ///
  /// Returns `false` if the player is not cached.
  Future<bool> removeAudio(String playerId) async {
    log('removeAudio $playerId', name: _nameLog);
    if (!await _checkExistCache(playerId)) return false;
    if (_audioCacheType[playerId] == AudioInAppType.background) {
      final player = _audioBackgroundCacheMap[playerId];
      if (player != null) await player.dispose();
      _audioBackgroundCacheMap.remove(playerId);
      _audioBackgroundPlayingIds.remove(playerId);
    }
    if (_audioCacheType[playerId] == AudioInAppType.determined) {
      final player = _audioCacheMap[playerId];
      if (player != null) await player.dispose();
      _audioCacheMap.remove(playerId);
    }
    _audioCacheType.remove(playerId);
    _audioBackgroundCacheList.remove(playerId);
    return true;
  }

  /// Returns the set of all cached player IDs (both determined and background).
  Set<String> get cachedPlayerIds => {
    ..._audioCacheMap.keys,
    ..._audioBackgroundCacheMap.keys,
  };

  /// Whether the user has granted audio permission.
  ///
  /// By default set to `true`. If set to `false`, no cached sound will play.
  bool get audioPermissionUser => _audioPermissionUser;

  set audioPermissionUser(bool value) {
    _audioPermissionUser = value;
  }

  // --- Private methods ---

  Future<bool> _checkExistCache(String playerId) async {
    if (_audioCacheType[playerId] == null) {
      log('ERROR', name: _nameLog);
      log('PlayerID $playerId is not cached', name: _nameLog);
      log('Call the function "createNewAudioCache"', name: _nameLog);
      return false;
    }
    return true;
  }

  Future<void> _playDetermined(String playerId) async {
    log('_playDetermined $playerId', name: _nameLog);
    final player = _audioCacheMap[playerId];
    if (player == null) return;
    if (player.state == PlayerState.playing) {
      await player.stop();
    }
    await player.resume();
  }

  Future<void> _playBackground(String playerId) async {
    log('_playBackground $playerId', name: _nameLog);
    final player = _audioBackgroundCacheMap[playerId];
    if (player == null) return;
    await player.resume();
    _audioBackgroundPlayingIds.add(playerId);
  }
}
