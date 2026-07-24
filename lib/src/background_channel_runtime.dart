import 'dart:async';

import 'package:audio_in_app/src/background_channel_state.dart';
import 'package:audio_in_app/src/channel_audio_backend.dart';
import 'package:audio_in_app/src/channel_scheduler.dart';
import 'package:audio_in_app/src/serial_executor.dart';

final class ChannelVoiceId {
  const ChannelVoiceId(this.value);

  final int value;

  @override
  bool operator ==(Object other) =>
      other is ChannelVoiceId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class BackgroundChannelRuntime<Source, BusToken, VoiceToken> {
  BackgroundChannelRuntime({
    required this.channelId,
    required double volume,
    required ChannelAudioBackend<Source, BusToken, VoiceToken> backend,
    required ChannelScheduler scheduler,
    required SerialExecutor executor,
    required Source? Function(String playerId) sourceFor,
    required double Function(String playerId) trackVolumeFor,
  }) : state = BackgroundChannelState<ChannelVoiceId>(volume: volume),
       _backend = backend,
       _scheduler = scheduler,
       _executor = executor,
       _sourceFor = sourceFor,
       _trackVolumeFor = trackVolumeFor,
       _bus = backend.createBus(name: channelId);

  final String channelId;
  final BackgroundChannelState<ChannelVoiceId> state;
  final ChannelAudioBackend<Source, BusToken, VoiceToken> _backend;
  final ChannelScheduler _scheduler;
  final SerialExecutor _executor;
  final Source? Function(String playerId) _sourceFor;
  final double Function(String playerId) _trackVolumeFor;
  final BusToken _bus;

  final Map<ChannelVoiceId, VoiceToken> _handles = {};
  final Map<ChannelVoiceId, ScheduledChannelTask> _fadeTasks = {};
  VoiceToken? _busHandle;
  var _nextVoiceId = 1;
  bool _disposed = false;

  String? get activePlayerId => state.targetPlayerId;
  bool get isPaused => state.isPaused;
  bool get isPlaying {
    _reconcileInvalidVoices();
    return _handles.values.any(_backend.isVoiceValid);
  }

  bool isPlayerActive(String playerId) {
    _reconcileInvalidVoices();
    for (final snapshot in state.voices.where(
      (voice) => voice.playerId == playerId,
    )) {
      final handle = _handles[snapshot.voiceId];
      if (handle != null && _backend.isVoiceValid(handle)) return true;
    }
    return false;
  }

  bool containsPlayer(String playerId) =>
      state.voices.any((voice) => voice.playerId == playerId) ||
      (state.hasPendingTransition && state.targetPlayerId == playerId);

  Iterable<VoiceToken> get activeHandles => List.unmodifiable(_handles.values);

  Future<bool> setVolume(double volume) async {
    _checkNotDisposed();
    state.setVolume(volume);
    final master = _busHandle;
    if (master != null && _backend.isVoiceValid(master)) {
      _backend.setVoiceVolume(master, volume);
    }
    return true;
  }

  Future<bool> play({
    required String playerId,
    required Duration transitionDuration,
  }) async {
    _checkNotDisposed();
    _reconcileInvalidVoices();
    final preparation = state.prepareTransition(
      playerId: playerId,
      duration: transitionDuration,
    );
    if (preparation.isNoop) return true;

    final Source? source = _sourceFor(playerId);
    if (source == null) {
      state.abortStart(preparation);
      return false;
    }

    ChannelVoiceId logicalId;
    VoiceToken handle;
    final reusedId = preparation.reusedVoiceId;
    if (reusedId != null) {
      final reusedHandle = _handles[reusedId];
      if (reusedHandle == null || !_backend.isVoiceValid(reusedHandle)) {
        state.abortStart(preparation);
        return false;
      }
      logicalId = reusedId;
      handle = reusedHandle;
    } else {
      if (!_ensureBusActive()) {
        state.abortStart(preparation);
        return false;
      }
      try {
        handle = _backend.playLooping(
          _bus,
          source,
          volume: preparation.initialGain * _trackVolumeFor(playerId),
          paused: state.isPaused,
        );
      } catch (_) {
        state.abortStart(preparation);
        return false;
      }
      if (_backend.isErrorVoice(handle) || !_backend.isVoiceValid(handle)) {
        state.abortStart(preparation);
        return false;
      }
      logicalId = ChannelVoiceId(_nextVoiceId++);
      _handles[logicalId] = handle;
    }

    final batch = state.commitStarted(
      preparation: preparation,
      voiceId: logicalId,
    );
    if (!batch.accepted) {
      if (reusedId == null) {
        _handles.remove(logicalId);
        await _safeStop(handle);
      }
      return false;
    }

    try {
      _backend.setVoiceProtected(handle, true);
      await _execute(batch);
      return true;
    } catch (_) {
      if (reusedId == null) {
        state.voiceInvalidated(logicalId);
        _handles.remove(logicalId);
        await _safeStop(handle);
      }
      return false;
    }
  }

  Future<bool> stop({required Duration fadeOutDuration}) async {
    _checkNotDisposed();
    final batch = state.stop(duration: fadeOutDuration);
    await _execute(batch);
    return true;
  }

  Future<bool> pause(ChannelPauseReason reason) async {
    _checkNotDisposed();
    state.pause(reason);
    for (final task in _fadeTasks.values) {
      task.pause();
    }
    _setAllPaused(true);
    return true;
  }

  Future<bool> resume(ChannelPauseReason reason) async {
    _checkNotDisposed();
    state.resume(reason);
    if (state.isPaused) return true;
    _setAllPaused(false);
    for (final entry in _fadeTasks.entries.toList()) {
      final snapshot = _snapshotFor(entry.key);
      final handle = _handles[entry.key];
      if (snapshot != null &&
          handle != null &&
          _backend.isVoiceValid(handle) &&
          entry.value.remaining > Duration.zero) {
        _backend.fadeVoiceVolume(
          handle,
          to: snapshot.targetGain * _trackVolumeFor(snapshot.playerId),
          duration: entry.value.remaining,
        );
      }
      entry.value.resume();
    }
    return true;
  }

  Future<void> refreshTrackVolume(String playerId) async {
    _checkNotDisposed();
    for (final snapshot in state.voices.where(
      (voice) => voice.playerId == playerId,
    )) {
      final handle = _handles[snapshot.voiceId];
      if (handle == null || !_backend.isVoiceValid(handle)) continue;
      final task = _fadeTasks[snapshot.voiceId];
      final target = snapshot.targetGain * _trackVolumeFor(playerId);
      if (task != null && task.isActive && task.remaining > Duration.zero) {
        _backend.setVoiceVolume(handle, _backend.getVoiceVolume(handle));
        _backend.fadeVoiceVolume(handle, to: target, duration: task.remaining);
      } else {
        _backend.setVoiceVolume(handle, target);
      }
    }
  }

  Future<void> removePlayer(String playerId) async {
    if (_disposed) return;
    await _execute(state.removePlayer(playerId));
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _scheduler.cancelAll();
    final handles = _handles.values.toList(growable: false);
    _handles.clear();
    state.invalidateAll();
    for (final handle in handles) {
      await _safeStop(handle);
    }
    final master = _busHandle;
    if (master != null && _backend.isVoiceValid(master)) {
      _backend.setVoiceProtected(master, false);
    }
    _backend.disposeBus(_bus);
    _busHandle = null;
  }

  bool _ensureBusActive() {
    final current = _busHandle;
    if (current != null && _backend.isVoiceValid(current)) return true;
    if (!_backend.isBusUsable(_bus)) return false;
    try {
      final handle = _backend.activateBus(
        _bus,
        volume: state.volume,
        paused: state.isPaused,
      );
      if (_backend.isErrorVoice(handle) || !_backend.isVoiceValid(handle)) {
        return false;
      }
      _backend.setVoiceProtected(handle, true);
      _busHandle = handle;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _execute(ChannelCommandBatch<ChannelVoiceId> batch) async {
    for (final command in batch.commands) {
      switch (command) {
        case FadeVoiceCommand<ChannelVoiceId>():
          await _fade(command);
        case StopVoiceCommand<ChannelVoiceId>():
          await _stopLogicalVoice(command.voiceId);
      }
    }
  }

  Future<void> _fade(FadeVoiceCommand<ChannelVoiceId> command) async {
    final handle = _handles[command.voiceId];
    final snapshot = _snapshotFor(command.voiceId);
    if (handle == null || snapshot == null || !_backend.isVoiceValid(handle)) {
      state.voiceInvalidated(command.voiceId);
      _handles.remove(command.voiceId);
      return;
    }
    _fadeTasks.remove(command.voiceId)?.cancel();
    _backend.fadeVoiceVolume(
      handle,
      to: command.targetGain * _trackVolumeFor(snapshot.playerId),
      duration: command.duration,
    );
    late final ScheduledChannelTask task;
    task = _scheduler.schedule(command.duration, () async {
      _fadeTasks.remove(command.voiceId);
      try {
        await _executor.run(() async {
          if (_disposed) return;
          if (command.targetGain == 0) {
            if (state.completeVoiceExit(
              voiceId: command.voiceId,
              exitRevision: command.revision,
            )) {
              await _stopLogicalVoice(command.voiceId);
            }
          } else {
            state.completeVoiceFade(command.voiceId);
          }
        });
      } on SerialExecutorClosedException {
        // Detached invalidates pending cleanup.
      }
    });
    _fadeTasks[command.voiceId] = task;
    if (state.isPaused) task.pause();
  }

  Future<void> _stopLogicalVoice(ChannelVoiceId voiceId) async {
    _fadeTasks.remove(voiceId)?.cancel();
    final handle = _handles.remove(voiceId);
    state.voiceInvalidated(voiceId);
    if (handle == null) return;
    if (_backend.isVoiceValid(handle)) {
      _backend.setVoiceProtected(handle, false);
      await _safeStop(handle);
    }
  }

  void _setAllPaused(bool paused) {
    final master = _busHandle;
    if (master != null && _backend.isVoiceValid(master)) {
      _backend.setVoicePaused(master, paused);
    }
    for (final handle in _handles.values) {
      if (_backend.isVoiceValid(handle)) {
        _backend.setVoicePaused(handle, paused);
      }
    }
  }

  void _reconcileInvalidVoices() {
    for (final entry in _handles.entries.toList()) {
      if (_backend.isVoiceValid(entry.value)) continue;
      _fadeTasks.remove(entry.key)?.cancel();
      _handles.remove(entry.key);
      state.voiceInvalidated(entry.key);
    }
  }

  ChannelVoiceSnapshot<ChannelVoiceId>? _snapshotFor(ChannelVoiceId id) {
    for (final snapshot in state.voices) {
      if (snapshot.voiceId == id) return snapshot;
    }
    return null;
  }

  Future<void> _safeStop(VoiceToken handle) async {
    try {
      await _backend.stopVoice(handle);
    } catch (_) {
      // The voice may already have ended or been stolen.
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('Channel $channelId has been disposed.');
    }
  }
}
