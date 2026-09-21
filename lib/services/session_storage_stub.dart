// Outside the browser sessionStorage does not exist; there the keychain does this job.
String? readSessionStorage(String key) => null;
void writeSessionStorage(String key, String value) {}
void removeSessionStorage(String key) {}
