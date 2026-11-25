# BMS device-local SQLite storage

## Changes in this working copy

- Windows initializes `sqflite_common_ffi` before `runApp`.
- Windows SQLite is stored under the app's private Application Support directory
  in a `databases/bms_offline.db` subfolder, not in `.dart_tool`.
- Android continues to use `getDatabasesPath()` and its app-private SQLite location.
- `sqflite_common_ffi` and `path_provider` are runtime dependencies.
- Android backup is disabled so the local database is not restored from Android
  cloud/device backup onto another installation.

## Important uninstall behaviour

- Android removes app-private database data on uninstall. `android:allowBackup="false"`
  is set to prevent automatic backup/restore of that app data.
- Windows database data is stored in the user's Application Support directory.
  Deleting only the `.exe` or application folder does NOT necessarily delete this data.
  For a commercial Windows release, package the app as MSIX (or provide an installer/
  uninstaller that removes the app-specific data directory) if uninstall/reinstall
  must always start with a fresh database.
- Do not manually delete the old `.dart_tool/sqflite_common_ffi/databases/bms_offline.db`
  until any test data in it has been backed up or is confirmed disposable. This build
  no longer uses that development database path on Windows.

## Verification still required on the developer's Windows machine

Run from the project root:

```powershell
flutter pub get
dart format lib/main.dart lib/services/sqlite_database_service.dart
flutter analyze
flutter test
flutter run -d windows
```

Then verify a fresh signup, close/reopen login, and persistence of test Company/Sales/Stock
records. Also run Android regression tests/build to confirm existing Android behaviour.
