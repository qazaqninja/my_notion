import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

bool _loaded = false;

/// Load .env once per test run. Reads the file directly from disk and passes
/// its contents to `dotenv.testLoad` — `dotenv.load(fileName:)` uses Flutter's
/// asset bundle, which isn't wired up under `flutter test`. If .env is absent,
/// initializes empty so `dotenv.env[key]` returns null (rather than throwing
/// NotInitializedError) — letting tests use `?? placeholder` fallbacks.
Future<void> loadTestEnv() async {
  if (_loaded) return;
  final envFile = File('.env');
  final contents =
      envFile.existsSync() ? await envFile.readAsString() : '';
  dotenv.testLoad(fileInput: contents);
  _loaded = true;
}
