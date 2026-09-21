import 'package:web/web.dart' as web;

// sessionStorage, not localStorage: it lives as long as the tab is open and survives a page
// reload, but is not left behind on disk when the browser closes.
String? readSessionStorage(String key) => web.window.sessionStorage.getItem(key);
void writeSessionStorage(String key, String value) => web.window.sessionStorage.setItem(key, value);
void removeSessionStorage(String key) => web.window.sessionStorage.removeItem(key);
