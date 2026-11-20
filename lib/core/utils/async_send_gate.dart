/// Prevents duplicate network writes from rapid taps.
///
/// Runs at most one [run] action at a time; concurrent attempts return `false`
/// without invoking the action. The gate always reopens, including on failure.
class AsyncSendGate {
  bool _inFlight = false;

  bool get isBusy => _inFlight;

  Future<bool> run(Future<void> Function() action) async {
    if (_inFlight) return false;
    _inFlight = true;
    try {
      await action();
      return true;
    } finally {
      _inFlight = false;
    }
  }
}
