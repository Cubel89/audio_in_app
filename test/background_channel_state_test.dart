import 'package:audio_in_app/src/background_channel_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackgroundChannelState', () {
    test('validates volume, player IDs and durations', () {
      expect(
        () => BackgroundChannelState<int>(volume: double.nan),
        throwsArgumentError,
      );
      expect(
        () => BackgroundChannelState<int>(volume: -0.1),
        throwsArgumentError,
      );
      final state = BackgroundChannelState<int>();
      expect(() => state.setVolume(double.infinity), throwsArgumentError);
      expect(() => state.prepareTransition(playerId: ' '), throwsArgumentError);
      expect(
        () => state.prepareTransition(
          playerId: 'a',
          duration: const Duration(milliseconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('first immediate play becomes stable without fade commands', () {
      final state = BackgroundChannelState<int>();
      final prep = state.prepareTransition(playerId: 'a');
      expect(prep.requiresNewVoice, isTrue);
      expect(prep.initialGain, 1);

      final batch = state.commitStarted(preparation: prep, voiceId: 1);

      expect(batch.accepted, isTrue);
      expect(batch.commands, isEmpty);
      expect(state.targetPlayerId, 'a');
      expect(state.voices.single.phase, ChannelVoicePhase.stable);
    });

    test('same pending and active target are idempotent', () {
      final state = BackgroundChannelState<int>();
      final pending = state.prepareTransition(playerId: 'a');
      expect(state.prepareTransition(playerId: 'a'), same(pending));
      state.commitStarted(preparation: pending, voiceId: 1);
      final revision = state.revision;

      final noop = state.prepareTransition(playerId: 'a');

      expect(noop.isNoop, isTrue);
      expect(state.revision, revision);
    });

    test('failed start preserves previous target', () {
      final state = BackgroundChannelState<int>();
      final a = state.prepareTransition(playerId: 'a');
      state.commitStarted(preparation: a, voiceId: 1);
      final b = state.prepareTransition(
        playerId: 'b',
        duration: const Duration(seconds: 2),
      );

      expect(state.abortStart(b), isTrue);
      expect(state.targetPlayerId, 'a');
      expect(state.voices.single.voiceId, 1);
    });

    test('late commit after stop emits compensating stop', () {
      final state = BackgroundChannelState<int>();
      final prep = state.prepareTransition(playerId: 'a');
      state.stop();

      final batch = state.commitStarted(preparation: prep, voiceId: 9);

      expect(batch.accepted, isFalse);
      expect(batch.commands.single, isA<StopVoiceCommand<int>>());
      expect(state.isEmpty, isTrue);
    });

    test('A to B to C only current exit revisions can clean voices', () {
      final state = BackgroundChannelState<int>();
      final a = state.prepareTransition(playerId: 'a');
      state.commitStarted(preparation: a, voiceId: 1);
      final b = state.prepareTransition(
        playerId: 'b',
        duration: const Duration(seconds: 2),
      );
      final batchB = state.commitStarted(preparation: b, voiceId: 2);
      final oldExitRevision =
          (batchB.commands.first as FadeVoiceCommand<int>).revision;
      final c = state.prepareTransition(
        playerId: 'c',
        duration: const Duration(seconds: 2),
      );
      state.commitStarted(preparation: c, voiceId: 3);

      expect(
        state.completeVoiceExit(voiceId: 1, exitRevision: oldExitRevision),
        isFalse,
      );
      final exits = state.voices
          .where((voice) => voice.phase == ChannelVoicePhase.exiting)
          .toList();
      expect(exits.map((voice) => voice.voiceId), containsAll([1, 2]));
      for (final exit in exits) {
        state.elapse(const Duration(seconds: 2));
        expect(
          state.completeVoiceExit(
            voiceId: exit.voiceId,
            exitRevision: exit.exitRevision!,
          ),
          isTrue,
        );
      }
      expect(state.voices.single.voiceId, 3);
    });

    test('A to B to A reuses the living A voice', () {
      final state = BackgroundChannelState<int>();
      final a = state.prepareTransition(playerId: 'a');
      state.commitStarted(preparation: a, voiceId: 1);
      final b = state.prepareTransition(
        playerId: 'b',
        duration: const Duration(seconds: 3),
      );
      state.commitStarted(preparation: b, voiceId: 2);

      final backToA = state.prepareTransition(
        playerId: 'a',
        duration: const Duration(seconds: 1),
      );

      expect(backToA.requiresNewVoice, isFalse);
      expect(backToA.reusedVoiceId, 1);
      state.commitStarted(preparation: backToA, voiceId: 1);
      expect(state.targetVoiceId, 1);
      expect(
        state.voices.where((voice) => voice.playerId == 'a'),
        hasLength(1),
      );
    });

    test('command batches are immutable snapshots', () {
      final state = BackgroundChannelState<int>();
      final a = state.prepareTransition(playerId: 'a');
      state.commitStarted(preparation: a, voiceId: 1);
      final b = state.prepareTransition(
        playerId: 'b',
        duration: const Duration(seconds: 2),
      );
      final firstBatch = state.commitStarted(preparation: b, voiceId: 2);
      final snapshot = List.of(firstBatch.commands);
      final c = state.prepareTransition(
        playerId: 'c',
        duration: const Duration(seconds: 1),
      );
      state.commitStarted(preparation: c, voiceId: 3);

      expect(firstBatch.commands, snapshot);
      expect(() => firstBatch.commands.clear(), throwsUnsupportedError);
    });

    test('pause reasons compose and freeze audible time', () {
      final state = BackgroundChannelState<int>();
      final prep = state.prepareTransition(
        playerId: 'a',
        duration: const Duration(seconds: 4),
      );
      state.commitStarted(preparation: prep, voiceId: 1);
      state.elapse(const Duration(seconds: 1));
      expect(state.voices.single.remainingFade, const Duration(seconds: 3));

      state.pause(ChannelPauseReason.channel);
      state.pause(ChannelPauseReason.lifecycle);
      state.elapse(const Duration(seconds: 2));
      expect(state.voices.single.remainingFade, const Duration(seconds: 3));
      state.resume(ChannelPauseReason.lifecycle);
      expect(state.isPaused, isTrue);
      state.resume(ChannelPauseReason.channel);
      state.elapse(const Duration(seconds: 3));
      expect(state.voices.single.phase, ChannelVoicePhase.stable);
    });

    test('remove target leaves channel without promoting an exiting voice', () {
      final state = BackgroundChannelState<int>();
      final a = state.prepareTransition(playerId: 'a');
      state.commitStarted(preparation: a, voiceId: 1);
      final b = state.prepareTransition(
        playerId: 'b',
        duration: const Duration(seconds: 2),
      );
      state.commitStarted(preparation: b, voiceId: 2);

      final batch = state.removePlayer('b');

      expect(batch.commands, hasLength(1));
      expect(state.targetPlayerId, isNull);
      expect(state.voices.single.playerId, 'a');
      expect(state.voices.single.phase, ChannelVoicePhase.exiting);
    });

    test('invalidateAll makes pending commits obsolete', () {
      final state = BackgroundChannelState<int>();
      final prep = state.prepareTransition(playerId: 'a');
      state.invalidateAll();

      final late = state.commitStarted(preparation: prep, voiceId: 4);

      expect(late.accepted, isFalse);
      expect(late.commands.single, isA<StopVoiceCommand<int>>());
      expect(state.isEmpty, isTrue);
    });

    test('deterministic operation sequence preserves invariants', () {
      final state = BackgroundChannelState<int>();
      var nextVoice = 1;
      for (var index = 0; index < 40; index++) {
        final id = 'track_${index % 4}';
        final prep = state.prepareTransition(
          playerId: id,
          duration: Duration(milliseconds: (index % 3) * 100),
        );
        if (!prep.isNoop) {
          final voiceId = prep.reusedVoiceId ?? nextVoice++;
          state.commitStarted(preparation: prep, voiceId: voiceId);
        }
        if (index.isEven) {
          state.elapse(const Duration(milliseconds: 50));
        }
        if (index % 7 == 0) {
          final due = List.of(state.dueExits);
          for (final voice in due) {
            state.completeVoiceExit(
              voiceId: voice.voiceId,
              exitRevision: voice.exitRevision!,
            );
          }
        }

        final voices = state.voices;
        expect(
          voices.map((voice) => voice.voiceId).toSet(),
          hasLength(voices.length),
        );
        expect(
          voices.where((voice) => voice.voiceId == state.targetVoiceId).length,
          lessThanOrEqualTo(1),
        );
      }
    });
  });
}
