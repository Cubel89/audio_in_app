import 'dart:developer';

import 'package:audio_in_app/src/audio_in_app_type.dart';
import 'package:audio_in_app/src/background_channel_runtime.dart';
import 'package:audio_in_app/src/background_channel_state.dart';
import 'package:audio_in_app/src/channel_scheduler.dart';
import 'package:audio_in_app/src/serial_executor.dart';
import 'package:audio_in_app/src/soloud_channel_audio_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// A singleton class that manages audio playback in your app.
///
/// Supports two types of audio:
/// - [AudioInAppType.determined]: Short, one-shot sounds (buttons, effects).
/// - [AudioInAppType.background]: Looping audio (music, ambient). Multiple
///   background audios can play simultaneously with independent control.
///
/// Audio is automatically paused when the app goes to background and resumed
/// when it comes back to foreground.
///
/// Powered by the SoLoud (C++) audio engine via the `flutter_soloud` package.
class AudioInApp with WidgetsBindingObserver {
  static const _nameLog = 'AudioInApp';
  bool _isRegistered = false;
  bool _audioPermission = true;
  bool _audioPermissionUser = true;

  // Estado del motor: se inicializa una sola vez y de forma idempotente.
  bool _engineReady = false;
  Future<void>? _initFuture;

  // playerId -> recurso de audio cargado en memoria (AudioSource).
  final Map<String, AudioSource> _sources = {};
  // playerId -> tipo de reproducción.
  final Map<String, AudioInAppType> _types = {};
  // playerId -> volumen deseado (por defecto 1.0). Aplica a futuras voces.
  final Map<String, double> _volumes = {};
  // playerId -> voz de fondo (loop) actualmente sonando.
  final Map<String, SoundHandle> _bgHandles = {};
  // playerId -> última voz one-shot disparada (referencia de coherencia).
  final Map<String, SoundHandle> _determinedHandles = {};
  final Map<String, BackgroundChannelRuntime<AudioSource, Bus, SoundHandle>>
  _channels = {};
  final SoLoudChannelAudioBackend _channelBackend =
      const SoLoudChannelAudioBackend();
  SerialExecutor _channelExecutor = SerialExecutor();

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

  /// Inicializa el motor SoLoud una sola vez, de forma idempotente y segura.
  ///
  /// Cachea el [Future] de `init()` para que dos cargas en paralelo no llamen
  /// a `init()` dos veces (una segunda llamada con el motor ya inicializado
  /// dispararía internamente un `deinit()` que destruiría todo). Si la
  /// inicialización falla (p. ej. en Windows sin dispositivo de audio), no
  /// propaga la excepción: devuelve `false` y permite reintentar más adelante.
  Future<bool> _ensureEngine() async {
    if (_engineReady) return true;
    try {
      if (_channelExecutor.isClosed) {
        _channelExecutor = SerialExecutor();
      }
      _initFuture ??= SoLoud.instance.init();
      await _initFuture;
      _engineReady = true;
      return true;
    } catch (e) {
      log('No se pudo inicializar el motor de audio: $e', name: _nameLog);
      _initFuture = null; // permite reintentar en una próxima llamada
      return false;
    }
  }

  /// Disposes the [WidgetsBinding] observer.
  ///
  /// Note: this does NOT shut down the SoLoud engine. The engine is a global
  /// singleton that may be shared by other parts of the app, so it is left
  /// running on purpose.
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
      _logDebug('Paused');
      _audioPermission = false;
      for (final handle in _bgHandles.values) {
        try {
          if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
            SoLoud.instance.setPause(handle, true);
          }
        } catch (e) {
          log('ERROR pause: $e', name: _nameLog);
        }
      }
      if (!_channelExecutor.isClosed) {
        await _channelExecutor.run(() async {
          for (final channel in _channels.values) {
            await channel.pause(ChannelPauseReason.lifecycle);
          }
        });
      }
    }
    if (state == AppLifecycleState.resumed) {
      _logDebug('Resumed');
      _audioPermission = true;
      if (_audioPermissionUser) {
        for (final handle in _bgHandles.values) {
          try {
            if (SoLoud.instance.getIsValidVoiceHandle(handle)) {
              SoLoud.instance.setPause(handle, false);
            }
          } catch (e) {
            log('ERROR resume: $e', name: _nameLog);
          }
        }
        if (!_channelExecutor.isClosed) {
          await _channelExecutor.run(() async {
            for (final channel in _channels.values) {
              await channel.resume(ChannelPauseReason.lifecycle);
            }
          });
        }
      }
    }
    if (state == AppLifecycleState.detached) {
      // El isolate se está destruyendo. El motor SoLoud es un singleton NATIVO
      // (C++) que sobrevive al teardown del isolate dentro del mismo proceso
      // (p. ej. Android al re-crear la Activity sin matar el proceso). Si no
      // cerramos aquí el motor, sus `NativeCallable` de FFI siguen registrados
      // apuntando a un isolate ya muerto y, cuando el hilo de audio nativo
      // dispara voiceEnded/stateChanged, el VM aborta: SIGABRT "Callback
      // invoked after it has been deleted" en el siguiente arranque en frío.
      // `deinit()` libera esos callbacks (disposeNativeCallables internamente).
      // Solo en `detached` (no en `paused`): en `paused` deinit mataría el audio
      // al minimizar o al mostrar un anuncio.
      _logDebug('Detached');
      try {
        if (!_channelExecutor.isClosed) {
          await _channelExecutor.run(() async {
            for (final channel in _channels.values.toList()) {
              await channel.dispose();
            }
            _channels.clear();
          });
          await _channelExecutor.close();
        }
        if (SoLoud.instance.isInitialized) {
          SoLoud.instance.deinit();
        }
      } catch (e) {
        log('ERROR deinit on detached: $e', name: _nameLog);
      }
      _engineReady = false;
      _initFuture = null;
      _bgHandles.clear();
      _determinedHandles.clear();
      _sources.clear();
      _types.clear();
    }
  }

  /// Adds an audio file to the cache. This is required before playing.
  ///
  /// [playerId] is a unique identifier to reference this audio later.
  /// [route] is, depending on [source]:
  /// - [AudioInAppSource.asset] (default): the asset path relative to the
  ///   `assets` folder (e.g. `'audio/button.wav'`).
  /// - [AudioInAppSource.file]: an absolute path to a local file on the device
  ///   filesystem (e.g. `'/data/.../audios/note.m4a'`).
  /// [audioInAppType] defines the playback behavior:
  /// - [AudioInAppType.determined]: One-shot. Each play creates a new voice
  ///   (overlapping playback).
  /// - [AudioInAppType.background]: Looping. Multiple backgrounds can play simultaneously.
  /// [source] selects where the audio is loaded from. Defaults to
  /// [AudioInAppSource.asset] to preserve backwards compatibility: existing
  /// callers that omit it keep loading from assets exactly as before.
  ///
  /// Returns `true` if the audio was cached successfully, `false` on error.
  Future<bool> createNewAudioCache({
    required String playerId,
    required String route,
    required AudioInAppType audioInAppType,
    AudioInAppSource source = AudioInAppSource.asset,
  }) async {
    _initialize();
    if (!await _ensureEngine()) return false;
    _logDebug('createNewAudioCache $playerId');
    if (_channels.values.any((channel) => channel.containsPlayer(playerId))) {
      log(
        'PlayerID $playerId is active in a channel and cannot be recached',
        name: _nameLog,
      );
      return false;
    }
    try {
      final AudioSource audioSource;
      if (source == AudioInAppSource.file) {
        // Fichero local del dispositivo: SoLoud lo carga directo desde la ruta
        // absoluta, sin pasar por el rootBundle de assets.
        audioSource = await SoLoud.instance.loadFile(route);
      } else {
        // SoLoud.loadAsset usa rootBundle.load(key) con la clave en crudo, NO
        // antepone 'assets/' como hacía audioplayers (AudioCache prefix:'assets/').
        // Normalizamos para preservar la convención pública: las apps siguen
        // pasando rutas como 'audio/button.wav'.
        final key = route.startsWith('assets/') ? route : 'assets/$route';
        audioSource = await SoLoud.instance.loadAsset(key);
      }
      _sources[playerId] = audioSource;
      _types[playerId] = audioInAppType;
      _volumes[playerId] ??= 1.0;
    } catch (e) {
      log('ERROR', name: _nameLog);
      log(e.toString(), name: _nameLog);
      return false;
    }
    return true;
  }

  /// Creates an exclusive logical background channel.
  ///
  /// Calling this again with the same [channelId] is idempotent and updates its
  /// master [volume]. The channel remains available until the engine is
  /// detached. Invalid arguments throw [ArgumentError]; engine failures return
  /// `false`.
  Future<bool> createChannel({
    required String channelId,
    double volume = 1,
  }) async {
    _validateChannelId(channelId);
    _validateVolume(volume);
    _initialize();
    if (!await _ensureEngine()) return false;
    try {
      return await _channelExecutor.run(() async {
        final existing = _channels[channelId];
        if (existing != null) return existing.setVolume(volume);
        final channel = BackgroundChannelRuntime<AudioSource, Bus, SoundHandle>(
          channelId: channelId,
          volume: volume,
          backend: _channelBackend,
          scheduler: TimerChannelScheduler(),
          executor: _channelExecutor,
          sourceFor: (playerId) => _sources[playerId],
          trackVolumeFor: (playerId) => _volumes[playerId] ?? 1,
        );
        _channels[channelId] = channel;
        return true;
      });
    } catch (e) {
      log('ERROR createChannel: $e', name: _nameLog);
      return false;
    }
  }

  /// Plays [playerId] in an exclusive background channel.
  ///
  /// If another track is active, both are crossfaded over
  /// [transitionDuration]. The future completes once the transition is safely
  /// started, not after its duration. Only cached background audio is accepted.
  Future<bool> playChannel({
    required String channelId,
    required String playerId,
    Duration transitionDuration = Duration.zero,
  }) async {
    _validateChannelId(channelId);
    _validatePlayerIdArgument(playerId);
    _validateDuration(transitionDuration);
    if (!_audioPermission || !_audioPermissionUser) return false;
    if (!await _checkExistCache(playerId)) return false;
    if (_types[playerId] != AudioInAppType.background) return false;
    try {
      return await _channelExecutor.run(() async {
        final channel = _channels[channelId];
        if (channel == null) return false;
        return channel.play(
          playerId: playerId,
          transitionDuration: transitionDuration,
        );
      });
    } catch (e) {
      log('ERROR playChannel: $e', name: _nameLog);
      return false;
    }
  }

  /// Stops every voice managed by [channelId].
  ///
  /// With a positive [fadeOutDuration], voices fade out while the channel
  /// remains reusable.
  Future<bool> stopChannel({
    required String channelId,
    Duration fadeOutDuration = Duration.zero,
  }) async {
    _validateChannelId(channelId);
    _validateDuration(fadeOutDuration);
    try {
      return await _channelExecutor.run(() async {
        final channel = _channels[channelId];
        if (channel == null) return false;
        return channel.stop(fadeOutDuration: fadeOutDuration);
      });
    } catch (e) {
      log('ERROR stopChannel: $e', name: _nameLog);
      return false;
    }
  }

  /// Pauses all voices and transition timers in [channelId].
  Future<bool> pauseChannel({required String channelId}) async {
    _validateChannelId(channelId);
    try {
      return await _channelExecutor.run(() async {
        final channel = _channels[channelId];
        if (channel == null) return false;
        return channel.pause(ChannelPauseReason.channel);
      });
    } catch (e) {
      log('ERROR pauseChannel: $e', name: _nameLog);
      return false;
    }
  }

  /// Resumes [channelId] unless another pause reason is still active.
  Future<bool> resumeChannel({required String channelId}) async {
    _validateChannelId(channelId);
    if (!_audioPermission || !_audioPermissionUser) return false;
    try {
      return await _channelExecutor.run(() async {
        final channel = _channels[channelId];
        if (channel == null) return false;
        return channel.resume(ChannelPauseReason.channel);
      });
    } catch (e) {
      log('ERROR resumeChannel: $e', name: _nameLog);
      return false;
    }
  }

  /// Changes the master volume of [channelId] without canceling child fades.
  Future<bool> setChannelVolume({
    required String channelId,
    required double volume,
  }) async {
    _validateChannelId(channelId);
    _validateVolume(volume);
    try {
      return await _channelExecutor.run(() async {
        final channel = _channels[channelId];
        if (channel == null) return false;
        return channel.setVolume(volume);
      });
    } catch (e) {
      log('ERROR setChannelVolume: $e', name: _nameLog);
      return false;
    }
  }

  /// Current logical target in [channelId], or `null` if none is committed.
  String? activePlayerIdInChannel(String channelId) {
    _validateChannelId(channelId);
    return _channels[channelId]?.activePlayerId;
  }

  /// Whether [channelId] owns at least one valid background voice.
  bool isChannelPlaying(String channelId) {
    _validateChannelId(channelId);
    return _channels[channelId]?.isPlaying ?? false;
  }

  /// Whether [channelId] is effectively paused for any reason.
  bool isChannelPaused(String channelId) {
    _validateChannelId(channelId);
    return _channels[channelId]?.isPaused ?? false;
  }

  /// Starts playing the audio identified by [playerId].
  ///
  /// For [AudioInAppType.determined] audio: plays once. Each call creates a new
  /// voice, so the same effect can overlap with itself.
  /// For [AudioInAppType.background] audio: starts looping. Multiple background
  /// audios can play simultaneously. Use [stopBackground] to stop all, or
  /// [stop] to stop a specific one.
  ///
  /// Returns `false` if audio permission is disabled or the player is not cached.
  Future<bool> play({required String playerId}) async {
    if (!_audioPermission) return false;
    if (!_audioPermissionUser) return false;
    _logDebug('play $playerId');
    if (!await _checkExistCache(playerId)) return false;
    try {
      if (_types[playerId] == AudioInAppType.background) {
        await _playBackground(playerId);
      }
      if (_types[playerId] == AudioInAppType.determined) {
        await _playDetermined(playerId);
      }
    } catch (e) {
      log('ERROR play: $e', name: _nameLog);
      return false;
    }
    return true;
  }

  /// Stops the audio identified by [playerId].
  ///
  /// Works for both determined and background audio types. For determined audio,
  /// all overlapping voices of that sound are stopped.
  /// Other background audios will continue playing unaffected.
  ///
  /// Returns `false` if the player is not cached.
  Future<bool> stop({required String playerId}) async {
    _logDebug('stop $playerId');
    if (!await _checkExistCache(playerId)) return false;
    try {
      if (!_channelExecutor.isClosed) {
        await _channelExecutor.run(() async {
          for (final channel in _channels.values) {
            await channel.removePlayer(playerId);
          }
        });
      }
      if (_types[playerId] == AudioInAppType.background) {
        final handle = _bgHandles.remove(playerId);
        if (handle != null) await SoLoud.instance.stop(handle);
      }
      if (_types[playerId] == AudioInAppType.determined) {
        // Con solapado pueden coexistir varias voces del mismo efecto: paramos
        // todas las instancias vivas de ese recurso.
        final source = _sources[playerId];
        if (source != null) {
          for (final handle in source.handles.toList()) {
            await SoLoud.instance.stop(handle);
          }
        }
        _determinedHandles.remove(playerId);
      }
    } catch (e) {
      log('ERROR stop: $e', name: _nameLog);
      return false;
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
    try {
      if (playerId != null) {
        _logDebug('stopBackground $playerId');
        if (!await _checkExistCache(playerId)) return false;
        if (!_channelExecutor.isClosed) {
          await _channelExecutor.run(() async {
            for (final channel in _channels.values) {
              await channel.removePlayer(playerId);
            }
          });
        }
        final handle = _bgHandles.remove(playerId);
        if (handle != null) await SoLoud.instance.stop(handle);
      } else {
        _logDebug('stopBackground all');
        if (!_channelExecutor.isClosed) {
          await _channelExecutor.run(() async {
            for (final channel in _channels.values.toList()) {
              await channel.stop(fadeOutDuration: Duration.zero);
            }
          });
        }
        // Capturamos las claves vivas AHORA y las quitamos una a una. NO usamos
        // clear() al final: como hay `await` entre stops, otra música podría
        // registrarse en _bgHandles durante este bucle (p. ej. la de partida
        // que arranca justo tras parar la del menú). Un clear() ciego la
        // borraría del mapa dejándola sonando "huérfana" e imposible de parar
        // luego. Quitando solo las que existían al entrar, lo nuevo se respeta.
        for (final id in _bgHandles.keys.toList()) {
          final handle = _bgHandles.remove(id);
          if (handle != null) await SoLoud.instance.stop(handle);
        }
      }
    } catch (e) {
      log('ERROR stopBackground: $e', name: _nameLog);
      return false;
    }
    return true;
  }

  /// Changes the audio volume for [playerId]. Value between 0.0 and 1.0.
  ///
  /// Works independently per audio — changing one does not affect others.
  /// The value is remembered for future plays; if the audio is currently
  /// playing, the change is applied immediately.
  Future<void> setVol(String playerId, double vol) async {
    _logDebug('setVol $playerId');
    if (!await _checkExistCache(playerId)) return;
    _volumes[playerId] = vol;
    try {
      if (!_channelExecutor.isClosed) {
        await _channelExecutor.run(() async {
          for (final channel in _channels.values) {
            await channel.refreshTrackVolume(playerId);
          }
        });
      }
      final bgHandle = _bgHandles[playerId];
      if (bgHandle != null && SoLoud.instance.getIsValidVoiceHandle(bgHandle)) {
        SoLoud.instance.setVolume(bgHandle, vol);
      }
      final detHandle = _determinedHandles[playerId];
      if (detHandle != null &&
          SoLoud.instance.getIsValidVoiceHandle(detHandle)) {
        SoLoud.instance.setVolume(detHandle, vol);
      }
    } catch (e) {
      log('ERROR setVol: $e', name: _nameLog);
    }
  }

  /// Removes the audio from the cache and releases its resources.
  ///
  /// The audio will no longer play until it is re-cached using [createNewAudioCache].
  ///
  /// Returns `false` if the player is not cached.
  Future<bool> removeAudio(String playerId) async {
    _logDebug('removeAudio $playerId');
    if (!await _checkExistCache(playerId)) return false;
    try {
      if (!_channelExecutor.isClosed) {
        await _channelExecutor.run(() async {
          for (final channel in _channels.values) {
            await channel.removePlayer(playerId);
          }
        });
      }
      final source = _sources.remove(playerId);
      _bgHandles.remove(playerId);
      _determinedHandles.remove(playerId);
      _types.remove(playerId);
      _volumes.remove(playerId);
      // disposeSource para todas las voces vivas del recurso y libera memoria.
      if (source != null) await SoLoud.instance.disposeSource(source);
    } catch (e) {
      log('ERROR removeAudio: $e', name: _nameLog);
      return false;
    }
    return true;
  }

  /// Returns the set of all cached player IDs (both determined and background).
  Set<String> get cachedPlayerIds => _sources.keys.toSet();

  /// Whether the audio identified by [playerId] is currently active.
  ///
  /// Checks the last started voice (determined or background) and returns
  /// `false` once it has finished, so callers can detect completion of a
  /// one-shot sound (e.g. to reset a play/stop button). Note: a background
  /// voice that is paused (e.g. while the app is in the background) is still
  /// considered active and returns `true`.
  bool isPlaying(String playerId) {
    for (final channel in _channels.values) {
      if (channel.isPlayerActive(playerId)) return true;
    }
    final handle = _determinedHandles[playerId] ?? _bgHandles[playerId];
    if (handle == null) return false;
    try {
      return SoLoud.instance.getIsValidVoiceHandle(handle);
    } catch (_) {
      return false;
    }
  }

  /// Whether the user has granted audio permission.
  ///
  /// By default set to `true`. If set to `false`, no cached sound will play.
  bool get audioPermissionUser => _audioPermissionUser;

  set audioPermissionUser(bool value) {
    _audioPermissionUser = value;
  }

  // --- Private methods ---

  static void _validateChannelId(String channelId) {
    if (channelId.trim().isEmpty) {
      throw ArgumentError.value(channelId, 'channelId', 'Cannot be empty.');
    }
  }

  static void _validatePlayerIdArgument(String playerId) {
    if (playerId.trim().isEmpty) {
      throw ArgumentError.value(playerId, 'playerId', 'Cannot be empty.');
    }
  }

  static void _validateVolume(double volume) {
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw ArgumentError.value(volume, 'volume', 'Must be between 0 and 1.');
    }
  }

  static void _validateDuration(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Cannot be negative.');
    }
  }

  /// Traza informativa: solo se emite en modo debug para no ensuciar los logs
  /// en release (estas trazas se disparan en cada operación de audio). Los
  /// `log()` de error sí se mantienen siempre.
  void _logDebug(String message) {
    if (kDebugMode) log(message, name: _nameLog);
  }

  Future<bool> _checkExistCache(String playerId) async {
    if (_types[playerId] == null) {
      log('ERROR', name: _nameLog);
      log('PlayerID $playerId is not cached', name: _nameLog);
      log('Call the function "createNewAudioCache"', name: _nameLog);
      return false;
    }
    return true;
  }

  Future<void> _playDetermined(String playerId) async {
    _logDebug('_playDetermined $playerId');
    final source = _sources[playerId];
    if (source == null) return;
    // Solapado: cada disparo crea una voz nueva (no se reinicia la anterior).
    final handle = SoLoud.instance.play(
      source,
      volume: _volumes[playerId] ?? 1.0,
    );
    _determinedHandles[playerId] = handle;
  }

  Future<void> _playBackground(String playerId) async {
    _logDebug('_playBackground $playerId');
    final source = _sources[playerId];
    if (source == null) return;
    final existing = _bgHandles[playerId];
    // Idempotente: si la voz de fondo sigue viva, no creamos otra.
    if (existing != null && SoLoud.instance.getIsValidVoiceHandle(existing)) {
      if (SoLoud.instance.getPause(existing)) {
        SoLoud.instance.setPause(existing, false); // estaba pausada: reanudar
      }
      return;
    }
    // No hay voz viva (nunca sonó o terminó): creamos una nueva en loop.
    final handle = SoLoud.instance.play(
      source,
      volume: _volumes[playerId] ?? 1.0,
      looping: true,
    );
    _bgHandles[playerId] = handle;
  }
}
