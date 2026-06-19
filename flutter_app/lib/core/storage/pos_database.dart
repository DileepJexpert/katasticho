import 'package:flutter/foundation.dart';

import 'pos_database_stub.dart'
    if (dart.library.io) 'pos_database_ffi.dart' as impl;

/// Whether the offline POS store (sqflite) is usable on this build target.
/// Web has no native SQLite, so offline POS is disabled there — the back-office
/// runs on web, the POS counter runs on Windows desktop / Android.
bool get posOfflineSupported => !kIsWeb;

/// Configures the global sqflite database factory for the current platform.
/// Call once at startup BEFORE opening any database. No-op on web (where the
/// FFI factory isn't even compiled in) and on mobile (default factory is fine);
/// on Windows/Linux/macOS desktop it installs the `sqflite_common_ffi` factory.
void initPosDatabaseFactory() => impl.initPosDatabaseFactory();
