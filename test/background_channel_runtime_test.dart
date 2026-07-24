import 'dart:async';

import 'package:audio_in_app/src/background_channel_runtime.dart';
import 'package:audio_in_app/src/background_channel_state.dart';
import 'package:audio_in_app/src/channel_audio_backend.dart';
import 'package:audio_in_app/src/channel_scheduler.dart';
import 'package:audio_in_app/src/serial_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundChannelRuntime', () {
    late _FakeBackend backend;
    late _FakeScheduler scheduler;
    late SerialExecutor executor;
    late Map<String, double> trackVolumes;
    late BackgroundChannelRuntime<String, String, int> runtime;

    setUp(() {
      backend = _FakeBackend();
      scheduler = _FakeScheduler();
      executor = SerialExecutor();
      trackVolumes = {'a': 1, 'b': 0.4, 'c': 0.8};
      runtime = BackgroundChannelRuntime(
        channelId: 'music',
        volume: 0.78,
        backend: backend,
        scheduler: scheduler,
        executor: executor,
        sourceFor: (id) => {'a', 'b', 'c'}.contains(id) ? id : null,
        trackVolumeFor: (id) => trackVolumes[id] ?? 1,
      );
    });

    tearDown(() async {
      await runtime.dispose();
      await executor.close();
    });

    test('activates the bus lazily and plays the first source', () async {
      expect(backend.activatedBuses, isEmpty);

      expect(
        await runtime.play(playerId: 'a', transitionDuration: Duration.zero),
        isTrue,
      );

      expect(backend.activatedBuses, ['music']);
      expect(runtime.activePlayerId, 'a');
      expect(runtime.isPlayerActive('a'), isTrue);
      expect(backend.volumeOf(backend.masterHandle), 0.78);
    });

    test(
      'crossfades to nominal track volume and cleans outgoing voice',
      () async {
        await runtime.play(playerId: 'a', transitionDuration: Duration.zero);
        final aHandle = backend.lastChildHandle;

        expect(
          await runtime.play(
            playerId: 'b',
            transitionDuration: const Duration(seconds: 2),
          ),
          isTrue,
        );
        final bHandle = backend.lastChildHandle;

        expect(backend.fadeTargets[aHandle], 0);
        expect(backend.fadeTargets[bHandle], 0.4);
        expect(runtime.activePlayerId, 'b');

        await scheduler.fireAll();

        expect(backend.stopped, contains(aHandle));
        expect(backend.stopped, isNot(contains(bHandle)));
        expect(runtime.state.voices.single.playerId, 'b');
      },
    );

    test('failed destination keeps the previous target', () async {
      await runtime.play(playerId: 'a', transitionDuration: Duration.zero);
      backend.failNextPlay = true;

      final result = await runtime.play(
        playerId: 'b',
        transitionDuration: const Duration(seconds: 1),
      );

      expect(result, isFalse);
      expect(runtime.activePlayerId, 'a');
      expect(runtime.isPlayerActive('a'), isTrue);
    });

    test('channel volume only changes the bus master', () async {
      await runtime.play(playerId: 'a', transitionDuration: Duration.zero);
      final child = backend.lastChildHandle;

      await runtime.setVolume(0.5);

      expect(backend.volumeOf(backend.masterHandle), 0.5);
      expect(backend.volumeOf(child), 1);
    });

    test('pause reasons freeze timers and compose', () async {
      await runtime.play(
        playerId: 'a',
        transitionDuration: const Duration(seconds: 2),
      );
      await runtime.pause(ChannelPauseReason.channel);
      await runtime.pause(ChannelPauseReason.lifecycle);

      expect(scheduler.tasks.single.isPaused, isTrue);
      expect(backend.paused.values.every((value) => value), isTrue);

      await runtime.resume(ChannelPauseReason.lifecycle);
      expect(runtime.isPaused, isTrue);
      expect(scheduler.tasks.single.isPaused, isTrue);

      await runtime.resume(ChannelPauseReason.channel);
      expect(runtime.isPaused, isFalse);
      expect(scheduler.tasks.single.isPaused, isFalse);
    });

    test('set track volume rebuilds an active fade', () async {
      await runtime.play(
        playerId: 'a',
        transitionDuration: const Duration(seconds: 3),
      );
      final handle = backend.lastChildHandle;
      trackVolumes['a'] = 0.25;

      await runtime.refreshTrackVolume('a');

      expect(backend.fadeTargets[handle], 0.25);
    });

    test('immediate stop clears voices but keeps the bus reusable', () async {
      await runtime.play(playerId: 'a', transitionDuration: Duration.zero);
      final firstMaster = backend.masterHandle;

      expect(await runtime.stop(fadeOutDuration: Duration.zero), isTrue);
      expect(runtime.isPlaying, isFalse);
      expect(backend.isVoiceValid(firstMaster), isTrue);

      expect(
        await runtime.play(playerId: 'b', transitionDuration: Duration.zero),
        isTrue,
      );
      expect(backend.masterHandle, firstMaster);
    });
  });
}

final class _FakeBackend implements ChannelAudioBackend<String, String, int> {
  final Map<int, bool> valid = {};
  final Map<int, double> volumes = {};
  final Map<int, bool> paused = {};
  final Map<int, bool> protected = {};
  final Map<int, double> fadeTargets = {};
  final List<int> stopped = [];
  final List<String> activatedBuses = [];
  var _nextHandle = 1;
  var failNextPlay = false;
  var masterHandle = -1;
  var lastChildHandle = -1;

  @override
  String createBus({required String name}) => name;

  @override
  bool isBusUsable(String bus) => true;

  @override
  int activateBus(String bus, {required double volume, bool paused = false}) {
    activatedBuses.add(bus);
    masterHandle = _newVoice(volume, paused);
    return masterHandle;
  }

  @override
  int playLooping(
    String bus,
    String source, {
    required double volume,
    bool paused = false,
  }) {
    if (failNextPlay) {
      failNextPlay = false;
      return -1;
    }
    lastChildHandle = _newVoice(volume, paused);
    return lastChildHandle;
  }

  int _newVoice(double volume, bool isPaused) {
    final handle = _nextHandle++;
    valid[handle] = true;
    volumes[handle] = volume;
    paused[handle] = isPaused;
    return handle;
  }

  double volumeOf(int handle) => volumes[handle]!;

  @override
  bool isErrorVoice(int voice) => voice < 0;

  @override
  bool isVoiceValid(int voice) => valid[voice] ?? false;

  @override
  void setVoiceProtected(int voice, bool value) {
    protected[voice] = value;
  }

  @override
  double getVoiceVolume(int voice) => volumes[voice] ?? 0;

  @override
  void setVoiceVolume(int voice, double volume) {
    volumes[voice] = volume;
  }

  @override
  void fadeVoiceVolume(
    int voice, {
    required double to,
    required Duration duration,
  }) {
    fadeTargets[voice] = to;
  }

  @override
  void setVoicePaused(int voice, bool value) {
    paused[voice] = value;
  }

  @override
  bool isVoicePaused(int voice) => paused[voice] ?? false;

  @override
  Future<void> stopVoice(int voice) async {
    valid[voice] = false;
    stopped.add(voice);
  }

  @override
  void disposeBus(String bus) {
    if (masterHandle >= 0) valid[masterHandle] = false;
  }
}

final class _FakeScheduler implements ChannelScheduler {
  final List<_FakeTask> tasks = [];

  @override
  ScheduledChannelTask schedule(
    Duration delay,
    FutureOr<void> Function() callback,
  ) {
    final task = _FakeTask(delay, callback);
    tasks.add(task);
    return task;
  }

  Future<void> fireAll() async {
    for (final task in tasks.toList()) {
      await task.fire();
    }
  }

  @override
  void cancelAll() {
    for (final task in tasks) {
      task.cancel();
    }
  }
}

final class _FakeTask implements ScheduledChannelTask {
  _FakeTask(this._remaining, this._callback);

  Duration _remaining;
  final FutureOr<void> Function() _callback;
  bool _active = true;
  bool _paused = false;

  @override
  bool get isActive => _active;

  @override
  bool get isPaused => _paused;

  @override
  Duration get remaining => _active ? _remaining : Duration.zero;

  @override
  void pause() {
    if (_active) _paused = true;
  }

  @override
  void resume() {
    if (_active) _paused = false;
  }

  @override
  void cancel() {
    _active = false;
    _paused = false;
    _remaining = Duration.zero;
  }

  Future<void> fire() async {
    if (!_active || _paused) return;
    _active = false;
    _remaining = Duration.zero;
    await Future<void>.sync(_callback);
  }
}
