import 'dart:async';

/// Error returned to queued operations invalidated by [SerialExecutor.close].
final class SerialExecutorClosedException extends StateError {
  SerialExecutorClosedException()
    : super('The serial executor has been closed.');
}

/// Runs asynchronous mutations sequentially in submission order.
///
/// Closing the executor lets the currently running operation finish and rejects
/// operations that have not started yet. The executor is intentionally
/// non-reentrant: an operation must not await another operation submitted to
/// the same instance.
final class SerialExecutor {
  Future<void> _tail = Future<void>.value();
  bool _closed = false;
  int _generation = 0;

  bool get isClosed => _closed;

  Future<T> run<T>(FutureOr<T> Function() operation) {
    if (_closed) {
      return Future<T>.error(SerialExecutorClosedException());
    }

    final generation = _generation;
    final result = Completer<T>();

    _tail = _tail.then((_) async {
      if (_closed || generation != _generation) {
        result.completeError(SerialExecutorClosedException());
        return;
      }

      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });

    return result.future;
  }

  /// Rejects queued operations and completes after an in-flight operation ends.
  Future<void> close() {
    if (!_closed) {
      _closed = true;
      _generation++;
    }
    return _tail;
  }
}
