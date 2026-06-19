import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Desktop (Windows/Linux/macOS) needs the FFI SQLite factory — plain `sqflite`
/// is mobile-only. Android/iOS keep their default factory.
void initPosDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
