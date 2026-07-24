import 'dart:async';

/// A cancelable unit of scheduled channel work.
abstract interface class ScheduledChannelTask {
  /// Whether the callback has neither fired nor been canceled.
  bool get isActive;

  /// Whether countdown is currently suspended.
  bool get isPaused;

  /// Audible time left before the callback is invoked.
  Duration get remaining;

  /// Suspends the countdown while retaining [remaining].
  void pause();

  /// Continues a previously paused countdown.
  void resume();

  /// Prevents the callback from being invoked.
  void cancel();
}

/// Injectable scheduler used for fade cleanup and lifecycle-aware delays.
abstract interface class ChannelScheduler {
  ScheduledChannelTask schedule(
    Duration delay,
    FutureOr<void> Function() callback,
  );

  /// Cancels every task currently owned by this scheduler.
  void cancelAll();
}

/// [ChannelScheduler] implementation based on Dart [Timer] and [Stopwatch].
final class TimerChannelScheduler implements ChannelScheduler {
  final Set<_TimerChannelTask> _tasks = {};

  @override
  ScheduledChannelTask schedule(
    Duration delay,
    FutureOr<void> Function() callback,
  ) {
    if (delay.isNegative) {
      throw ArgumentError.value(delay, 'delay', 'Must not be negative.');
    }

    late final _TimerChannelTask task;
    task = _TimerChannelTask(
      delay: delay,
      callback: callback,
      onFinished: () => _tasks.remove(task),
    );
    _tasks.add(task);
    task.start();
    return task;
  }

  @override
  void cancelAll() {
    for (final task in _tasks.toList(growable: false)) {
      task.cancel();
    }
    _tasks.clear();
  }
}

final class _TimerChannelTask implements ScheduledChannelTask {
  _TimerChannelTask({
    required Duration delay,
    required FutureOr<void> Function() callback,
    required void Function() onFinished,
  }) : _remaining = delay,
       _callback = callback,
       _onFinished = onFinished;

  final FutureOr<void> Function() _callback;
  final void Function() _onFinished;
  final Stopwatch _stopwatch = Stopwatch();

  Timer? _timer;
  Duration _remaining;
  bool _active = true;
  bool _paused = false;

  void start() {
    if (!_active) return;
    _stopwatch
      ..reset()
      ..start();
    _timer = Timer(_remaining, _fire);
  }

  @override
  bool get isActive => _active;

  @override
  bool get isPaused => _active && _paused;

  @override
  Duration get remaining {
    if (!_active) return Duration.zero;
    if (_paused) return _remaining;
    return _subtractFloorZero(_remaining, _stopwatch.elapsed);
  }

  @override
  void pause() {
    if (!_active || _paused) return;
    _remaining = remaining;
    _timer?.cancel();
    _timer = null;
    _stopwatch
      ..stop()
      ..reset();
    _paused = true;
  }

  @override
  void resume() {
    if (!_active || !_paused) return;
    _paused = false;
    start();
  }

  @override
  void cancel() {
    if (!_active) return;
    _active = false;
    _paused = false;
    _timer?.cancel();
    _timer = null;
    _stopwatch
      ..stop()
      ..reset();
    _remaining = Duration.zero;
    _onFinished();
  }

  void _fire() {
    if (!_active || _paused) return;
    _active = false;
    _timer = null;
    _stopwatch
      ..stop()
      ..reset();
    _remaining = Duration.zero;
    _onFinished();
    unawaited(Future<void>.sync(_callback));
  }

  static Duration _subtractFloorZero(Duration left, Duration right) {
    final difference = left - right;
    return difference.isNegative ? Duration.zero : difference;
  }
}
