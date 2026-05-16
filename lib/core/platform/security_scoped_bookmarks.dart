import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin Dart wrapper around the macOS `quill/bookmarks` MethodChannel
/// implemented in `macos/Runner/AppDelegate.swift`.
///
/// The macOS App Sandbox grants the app per-launch access to folders the
/// user picks via `NSOpenPanel`. Without a security-scoped bookmark, that
/// access is gone after quit, and VaultBloc's auto-restore silently falls
/// back to the picker. This wrapper lets us:
///
/// - `save(path)` once after a successful pick → returns Base64-encoded
///   bookmark bytes that we persist in SharedPreferences in place of the
///   raw path.
/// - `resolve(bookmark)` on every launch → returns the resolved path with
///   `startAccessingSecurityScopedResource()` already invoked, so the
///   bloc can reindex normally.
///
/// On non-macOS platforms, `isSupported` is false and both methods are
/// no-ops that return null. The bloc treats null as "no bookmark
/// available — show the picker".
class SecurityScopedBookmarks {
  SecurityScopedBookmarks({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('quill/bookmarks');

  final MethodChannel _channel;

  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// Bookmark a folder path. Returns the Base64-encoded bookmark bytes on
  /// success, or null on failure / unsupported platform. The caller should
  /// persist the bytes in SharedPreferences (or similar durable store).
  Future<String?> save(String path) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('save', {'path': path});
    } on PlatformException {
      return null;
    }
  }

  /// Resolve a previously-saved bookmark back to a path. The Swift side
  /// calls `startAccessingSecurityScopedResource()` before returning, so
  /// the path is immediately accessible to file I/O. Returns null on
  /// failure (stale bookmark, sandbox revoked, etc.).
  Future<String?> resolve(String bookmark) async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('resolve', {
        'bookmark': bookmark,
      });
    } on PlatformException {
      return null;
    }
  }
}
