enum ChannelPauseReason { channel, lifecycle, gate }

enum ChannelVoicePhase { entering, stable, exiting }

sealed class ChannelCommand<VoiceId extends Object> {
  const ChannelCommand();
}

final class FadeVoiceCommand<VoiceId extends Object>
    extends ChannelCommand<VoiceId> {
  const FadeVoiceCommand({
    required this.voiceId,
    required this.targetGain,
    required this.duration,
    required this.revision,
  });

  final VoiceId voiceId;
  final double targetGain;
  final Duration duration;
  final int revision;
}

final class StopVoiceCommand<VoiceId extends Object>
    extends ChannelCommand<VoiceId> {
  const StopVoiceCommand({required this.voiceId, required this.revision});

  final VoiceId voiceId;
  final int revision;
}

final class ChannelCommandBatch<VoiceId extends Object> {
  ChannelCommandBatch({
    required this.revision,
    required Iterable<ChannelCommand<VoiceId>> commands,
    this.accepted = true,
  }) : commands = List<ChannelCommand<VoiceId>>.unmodifiable(commands);

  final int revision;
  final List<ChannelCommand<VoiceId>> commands;
  final bool accepted;

  bool get isEmpty => commands.isEmpty;
}

final class ChannelTransitionPreparation<VoiceId extends Object> {
  const ChannelTransitionPreparation._({
    required this.revision,
    required this.playerId,
    required this.duration,
    required this.initialGain,
    required this.reusedVoiceId,
    required this.isNoop,
  });

  factory ChannelTransitionPreparation.start({
    required int revision,
    required String playerId,
    required Duration duration,
    required double initialGain,
    VoiceId? reusedVoiceId,
  }) {
    return ChannelTransitionPreparation._(
      revision: revision,
      playerId: playerId,
      duration: duration,
      initialGain: initialGain,
      reusedVoiceId: reusedVoiceId,
      isNoop: false,
    );
  }

  factory ChannelTransitionPreparation.noop({
    required int revision,
    required String playerId,
  }) {
    return ChannelTransitionPreparation._(
      revision: revision,
      playerId: playerId,
      duration: Duration.zero,
      initialGain: 1,
      reusedVoiceId: null,
      isNoop: true,
    );
  }

  final int revision;
  final String playerId;
  final Duration duration;
  final double initialGain;
  final VoiceId? reusedVoiceId;
  final bool isNoop;

  bool get requiresNewVoice => !isNoop && reusedVoiceId == null;
}

final class ChannelVoiceSnapshot<VoiceId extends Object> {
  const ChannelVoiceSnapshot({
    required this.voiceId,
    required this.playerId,
    required this.phase,
    required this.currentGain,
    required this.targetGain,
    required this.remainingFade,
    required this.exitRevision,
  });

  final VoiceId voiceId;
  final String playerId;
  final ChannelVoicePhase phase;
  final double currentGain;
  final double targetGain;
  final Duration remainingFade;
  final int? exitRevision;
}

final class _ChannelVoice<VoiceId extends Object> {
  _ChannelVoice({
    required this.voiceId,
    required this.playerId,
    required this.currentGain,
  });

  final VoiceId voiceId;
  final String playerId;
  ChannelVoicePhase phase = ChannelVoicePhase.stable;
  double currentGain;
  double fadeStartGain = 1;
  double targetGain = 1;
  Duration totalFade = Duration.zero;
  Duration remainingFade = Duration.zero;
  int? exitRevision;

  ChannelVoiceSnapshot<VoiceId> snapshot() {
    return ChannelVoiceSnapshot(
      voiceId: voiceId,
      playerId: playerId,
      phase: phase,
      currentGain: currentGain,
      targetGain: targetGain,
      remainingFade: remainingFade,
      exitRevision: exitRevision,
    );
  }
}

/// Pure state machine for one exclusive background channel.
///
/// It never calls Flutter or an audio engine. The runtime prepares a
/// transition, starts (or reuses) the requested voice, then commits or aborts
/// the preparation. Every returned command is an immutable snapshot.
final class BackgroundChannelState<VoiceId extends Object> {
  BackgroundChannelState({double volume = 1}) : _volume = _validVolume(volume);

  final Map<VoiceId, _ChannelVoice<VoiceId>> _voices = {};
  final Set<ChannelPauseReason> _pauseReasons = {};
  int _revision = 0;
  double _volume;
  String? _targetPlayerId;
  VoiceId? _targetVoiceId;
  ChannelTransitionPreparation<VoiceId>? _pending;

  int get revision => _revision;
  double get volume => _volume;
  String? get targetPlayerId => _targetPlayerId;
  VoiceId? get targetVoiceId => _targetVoiceId;
  bool get hasPendingTransition => _pending != null;
  bool get isPaused => _pauseReasons.isNotEmpty;
  bool get isEmpty => _voices.isEmpty && _pending == null;

  Set<ChannelPauseReason> get pauseReasons =>
      Set<ChannelPauseReason>.unmodifiable(_pauseReasons);

  List<ChannelVoiceSnapshot<VoiceId>> get voices =>
      List.unmodifiable(_voices.values.map((voice) => voice.snapshot()));

  void setVolume(double value) {
    _volume = _validVolume(value);
  }

  ChannelTransitionPreparation<VoiceId> prepareTransition({
    required String playerId,
    Duration duration = Duration.zero,
  }) {
    _validatePlayerId(playerId);
    _validateDuration(duration);

    final pending = _pending;
    if (pending != null && pending.playerId == playerId) {
      return pending;
    }

    if (_targetPlayerId == playerId &&
        _targetVoiceId != null &&
        _voices.containsKey(_targetVoiceId)) {
      return ChannelTransitionPreparation.noop(
        revision: _revision,
        playerId: playerId,
      );
    }

    _revision++;
    final reusable = _voices.values
        .where((voice) => voice.playerId == playerId)
        .firstOrNull;
    final preparation = ChannelTransitionPreparation<VoiceId>.start(
      revision: _revision,
      playerId: playerId,
      duration: duration,
      initialGain: duration == Duration.zero ? 1 : 0,
      reusedVoiceId: reusable?.voiceId,
    );
    _pending = preparation;
    return preparation;
  }

  ChannelCommandBatch<VoiceId> commitStarted({
    required ChannelTransitionPreparation<VoiceId> preparation,
    required VoiceId voiceId,
  }) {
    if (preparation.isNoop) {
      return ChannelCommandBatch(revision: _revision, commands: const []);
    }

    if (!identical(_pending, preparation) ||
        preparation.revision != _revision) {
      return ChannelCommandBatch(
        revision: _revision,
        accepted: false,
        commands: [
          StopVoiceCommand(voiceId: voiceId, revision: preparation.revision),
        ],
      );
    }

    final reusedVoiceId = preparation.reusedVoiceId;
    if (reusedVoiceId != null && reusedVoiceId != voiceId) {
      throw StateError(
        'The committed voice does not match the reusable voice.',
      );
    }
    if (reusedVoiceId == null && _voices.containsKey(voiceId)) {
      throw StateError('Voice IDs must be unique.');
    }

    final target =
        _voices[voiceId] ??
        _ChannelVoice(
          voiceId: voiceId,
          playerId: preparation.playerId,
          currentGain: preparation.initialGain,
        );
    _voices[voiceId] = target;

    final commands = <ChannelCommand<VoiceId>>[];
    for (final voice in _voices.values.toList()) {
      if (voice.voiceId == voiceId) continue;
      _beginFade(
        voice,
        targetGain: 0,
        duration: preparation.duration,
        phase: ChannelVoicePhase.exiting,
        exitRevision: preparation.revision,
      );
      if (preparation.duration == Duration.zero) {
        _voices.remove(voice.voiceId);
        commands.add(
          StopVoiceCommand(
            voiceId: voice.voiceId,
            revision: preparation.revision,
          ),
        );
      } else {
        commands.add(
          FadeVoiceCommand(
            voiceId: voice.voiceId,
            targetGain: 0,
            duration: preparation.duration,
            revision: preparation.revision,
          ),
        );
      }
    }

    _beginFade(
      target,
      targetGain: 1,
      duration: preparation.duration,
      phase: preparation.duration == Duration.zero
          ? ChannelVoicePhase.stable
          : ChannelVoicePhase.entering,
    );
    target.exitRevision = null;
    if (preparation.duration > Duration.zero) {
      commands.add(
        FadeVoiceCommand(
          voiceId: voiceId,
          targetGain: 1,
          duration: preparation.duration,
          revision: preparation.revision,
        ),
      );
    }

    _targetPlayerId = preparation.playerId;
    _targetVoiceId = voiceId;
    _pending = null;
    return ChannelCommandBatch(
      revision: preparation.revision,
      commands: commands,
    );
  }

  bool abortStart(ChannelTransitionPreparation<VoiceId> preparation) {
    if (!identical(_pending, preparation) ||
        preparation.revision != _revision) {
      return false;
    }
    _pending = null;
    return true;
  }

  ChannelCommandBatch<VoiceId> stop({Duration duration = Duration.zero}) {
    _validateDuration(duration);
    _revision++;
    _pending = null;
    _targetPlayerId = null;
    _targetVoiceId = null;
    final commands = <ChannelCommand<VoiceId>>[];
    for (final voice in _voices.values.toList()) {
      if (duration == Duration.zero) {
        _voices.remove(voice.voiceId);
        commands.add(
          StopVoiceCommand(voiceId: voice.voiceId, revision: _revision),
        );
      } else {
        _beginFade(
          voice,
          targetGain: 0,
          duration: duration,
          phase: ChannelVoicePhase.exiting,
          exitRevision: _revision,
        );
        commands.add(
          FadeVoiceCommand(
            voiceId: voice.voiceId,
            targetGain: 0,
            duration: duration,
            revision: _revision,
          ),
        );
      }
    }
    return ChannelCommandBatch(revision: _revision, commands: commands);
  }

  ChannelCommandBatch<VoiceId> removePlayer(String playerId) {
    _validatePlayerId(playerId);
    _revision++;
    if (_pending?.playerId == playerId) _pending = null;
    final commands = <ChannelCommand<VoiceId>>[];
    for (final voice in _voices.values.toList()) {
      if (voice.playerId != playerId) continue;
      _voices.remove(voice.voiceId);
      commands.add(
        StopVoiceCommand(voiceId: voice.voiceId, revision: _revision),
      );
      if (_targetVoiceId == voice.voiceId) {
        _targetVoiceId = null;
        _targetPlayerId = null;
      }
    }
    return ChannelCommandBatch(revision: _revision, commands: commands);
  }

  bool voiceInvalidated(VoiceId voiceId) {
    final removed = _voices.remove(voiceId);
    if (removed == null) return false;
    if (_targetVoiceId == voiceId) {
      _targetVoiceId = null;
      _targetPlayerId = null;
    }
    return true;
  }

  bool completeVoiceExit({
    required VoiceId voiceId,
    required int exitRevision,
  }) {
    final voice = _voices[voiceId];
    if (voice == null ||
        voice.phase != ChannelVoicePhase.exiting ||
        voice.exitRevision != exitRevision ||
        _targetVoiceId == voiceId) {
      return false;
    }
    _voices.remove(voiceId);
    return true;
  }

  bool completeVoiceFade(VoiceId voiceId) {
    final voice = _voices[voiceId];
    if (voice == null || voice.phase != ChannelVoicePhase.entering) {
      return false;
    }
    voice
      ..phase = ChannelVoicePhase.stable
      ..currentGain = voice.targetGain
      ..remainingFade = Duration.zero;
    return true;
  }

  ChannelCommandBatch<VoiceId> invalidateAll() {
    _revision++;
    final commands = _voices.keys
        .map(
          (voiceId) =>
              StopVoiceCommand<VoiceId>(voiceId: voiceId, revision: _revision),
        )
        .toList(growable: false);
    _voices.clear();
    _pending = null;
    _targetPlayerId = null;
    _targetVoiceId = null;
    _pauseReasons.clear();
    return ChannelCommandBatch(revision: _revision, commands: commands);
  }

  void pause(ChannelPauseReason reason) => _pauseReasons.add(reason);

  void resume(ChannelPauseReason reason) => _pauseReasons.remove(reason);

  /// Advances the audible transition clock. Time does not advance while paused.
  void elapse(Duration elapsed) {
    _validateDuration(elapsed);
    if (isPaused || elapsed == Duration.zero) return;
    for (final voice in _voices.values) {
      if (voice.remainingFade == Duration.zero) continue;
      final previousRemaining = voice.remainingFade;
      final nextMicros = (previousRemaining - elapsed).inMicroseconds.clamp(
        0,
        1 << 62,
      );
      voice.remainingFade = Duration(microseconds: nextMicros);
      final totalMicros = voice.totalFade.inMicroseconds;
      final completedMicros = totalMicros - voice.remainingFade.inMicroseconds;
      final progress = totalMicros == 0 ? 1.0 : completedMicros / totalMicros;
      voice.currentGain =
          voice.fadeStartGain +
          ((voice.targetGain - voice.fadeStartGain) * progress);
      if (voice.remainingFade == Duration.zero &&
          voice.phase == ChannelVoicePhase.entering) {
        voice.phase = ChannelVoicePhase.stable;
      }
    }
  }

  List<FadeVoiceCommand<VoiceId>> resumeFadeCommands() {
    if (isPaused) return const [];
    return List.unmodifiable(
      _voices.values
          .where((voice) => voice.remainingFade > Duration.zero)
          .map(
            (voice) => FadeVoiceCommand(
              voiceId: voice.voiceId,
              targetGain: voice.targetGain,
              duration: voice.remainingFade,
              revision: voice.exitRevision ?? _revision,
            ),
          ),
    );
  }

  List<ChannelVoiceSnapshot<VoiceId>> get dueExits => List.unmodifiable(
    _voices.values
        .where(
          (voice) =>
              voice.phase == ChannelVoicePhase.exiting &&
              voice.remainingFade == Duration.zero,
        )
        .map((voice) => voice.snapshot()),
  );

  void _beginFade(
    _ChannelVoice<VoiceId> voice, {
    required double targetGain,
    required Duration duration,
    required ChannelVoicePhase phase,
    int? exitRevision,
  }) {
    voice
      ..phase = phase
      ..fadeStartGain = voice.currentGain
      ..targetGain = targetGain
      ..totalFade = duration
      ..remainingFade = duration
      ..exitRevision = exitRevision;
    if (duration == Duration.zero) {
      voice.currentGain = targetGain;
    }
  }

  static double _validVolume(double value) {
    if (!value.isFinite || value < 0 || value > 1) {
      throw ArgumentError.value(value, 'volume', 'Must be between 0 and 1.');
    }
    return value;
  }

  static void _validateDuration(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Cannot be negative.');
    }
  }

  static void _validatePlayerId(String playerId) {
    if (playerId.trim().isEmpty) {
      throw ArgumentError.value(playerId, 'playerId', 'Cannot be empty.');
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
