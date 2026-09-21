/// In the browser there is a single isolate and no background sync: there is nothing to lock.
Future<T?> withSyncLock<T>(Future<T> Function() action) => action();
