import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

const _name = 'managevity.sync.lock';

/// Runs [action] under a lock that holds across isolates, or returns null if another sync
/// is already running.
///
/// The app and the background task on Android are two isolates in the same process, each
/// with its own memory; a flag in a provider is invisible to the other one. Without a lock
/// they can both create the same lesson before either has saved the index — harmless with
/// CalDAV (fixed file name), but a duplicate event in the device calendar.
///
/// A file lock does not work here: that applies per process, and this *is* one process. The
/// IsolateNameServer does: registering a name succeeds for exactly one isolate at a time.
Future<T?> withSyncLock<T>(Future<T> Function() action) async {
  final port = ReceivePort();
  // The holder answers a ping, so that another isolate can tell it is still alive.
  final pings = port.listen((message) {
    if (message is SendPort) message.send(true);
  });
  try {
    if (!IsolateNameServer.registerPortWithName(port.sendPort, _name)) {
      if (await _holderAlive()) return null; // another isolate is busy
      // The holder died without cleaning up (the operating system may stop a background
      // task at any moment). Take over its lock.
      IsolateNameServer.removePortNameMapping(_name);
      if (!IsolateNameServer.registerPortWithName(port.sendPort, _name)) return null;
    }
    try {
      return await action();
    } finally {
      IsolateNameServer.removePortNameMapping(_name);
    }
  } finally {
    await pings.cancel();
    port.close();
  }
}

Future<bool> _holderAlive() async {
  final holder = IsolateNameServer.lookupPortByName(_name);
  if (holder == null) return false;
  final reply = ReceivePort();
  try {
    holder.send(reply.sendPort);
    return await reply.first.timeout(const Duration(seconds: 2), onTimeout: () => false) == true;
  } finally {
    reply.close();
  }
}
